// 《坎儿井》核心逻辑 —— C# 对照端口。
//
// 与 GDScript 主线（scripts/core/game_state.gd）功能等价，供偏好 C# 时使用。
// 两者**不要同时挂在场景里**：GameState.cs 没有 Godot 节点壳（不用 HTTPRequest，
// 改用 .NET 的 HttpClient 异步调用），只作为纯逻辑库被你自己的节点脚本调用。
//
// 用法示例（你自己的 Node 脚本里）：
//     var core = new Kanerjing.Core.GameCore("res://../data/numbers.json");
//     var result = await core.NarrateAsync("先看看第三口竖井", "lao_kanjiang");
//     GD.Print(result.Narration);
//
// 启用的前提：project.godot 里 dotnet/project/assembly_name 指向本项目（已配置为 Kanerjing）。

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Threading.Tasks;

namespace Kanerjing.Core
{
    /// <summary>AI 一次返回的结果。</summary>
    public sealed class NarrateResult
    {
        public string Narration = "";
        public string Speaker = "";
        public string Emotion = "";
        public List<Delta> Deltas = new();
        public List<string> MemoryAppend = new();
        public List<string> Suggestions = new();
        public bool Degraded;
        public string Mode = "demo";
        public string Reason = "";
        public double LatencyMs;
        public int TokensIn;
        public int TokensOut;
        public int CacheHitTokens;
        public int DroppedDeltas;
    }

    public sealed class Delta
    {
        public string Op = "";
        public string Path = "";
        public double Value;
    }

    /// <summary>
    /// 游戏核心：持有权威状态、应用经过门禁的状态增量、与本机 Python AI 服务通信。
    ///
    /// 与 GDScript 版共享同一份契约（ai_backend/schema.json）：
    ///   1. 数值只在本地算，模型只给意图
    ///   2. delta 必须过白名单 + 幅度夹紧
    ///   3. AI 不可用时静默降级，绝不中断游戏
    /// </summary>
    public sealed class GameCore
    {
        public const string SchemaVersion = "1.0";
        public const double MaxDeltaMagnitude = 25.0;

        private static readonly string[] AllowedPrefixes =
        {
            "resources.silver", "resources.food.", "resources.materials.",
            "resources.water.current", "stats.reputation", "stats.morale",
            "stats.security", "characters.",
        };

        private static readonly string[] CharacterIds =
        {
            "lao_kanjiang", "muqam_yiren", "hasake_qishou", "hanshang_zhanggui",
            "chuniang", "shenmi_lvren", "mafei_toumu",
        };

        private readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(60) };
        private readonly string _endpoint;
        private readonly JsonNode _numbers;

        /// <summary>权威状态。外部只读，改动一律走 ApplyDeltas。</summary>
        public JsonObject State { get; private set; }

        /// <summary>设为 true 则完全跳过网络，进入离线降级。</summary>
        public bool OfflineMode { get; set; }

        /// <summary>最近一次请求是否降级（网络失败或服务不可用）。</summary>
        public bool LastRequestDegraded { get; private set; }

        public GameCore(string numbersJsonPath = null)
        {
            var host = Environment.GetEnvironmentVariable("AI_HOST");
            var port = Environment.GetEnvironmentVariable("AI_PORT");
            _endpoint = $"http://{(string.IsNullOrEmpty(host) ? "127.0.0.1" : host)}:" +
                        $"{(string.IsNullOrEmpty(port) ? "8787" : port)}/narrate";

            _numbers = LoadNumbers(numbersJsonPath);
            State = InitialState(_numbers);
        }

        // -------------------------------------------------------------------
        // 数值与初始状态
        // -------------------------------------------------------------------

        private static JsonNode LoadNumbers(string path)
        {
            foreach (var candidate in new[]
                     {
                         path,
                         Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "data", "numbers.json"),
                         "res://../data/numbers.json",
                         "data/numbers.json",
                     })
            {
                if (string.IsNullOrEmpty(candidate) || !File.Exists(candidate)) continue;
                try
                {
                    return JsonNode.Parse(File.ReadAllText(candidate, Encoding.UTF8));
                }
                catch (JsonException ex)
                {
                    GD.PushError($"numbers.json 解析失败 {candidate}: {ex.Message}");
                }
            }
            GD.PushWarning("未找到 numbers.json，使用内置极简数值。");
            return FallbackNumbers();
        }

        private static JsonNode FallbackNumbers() => JsonNode.Parse("""
        {
          "karez": {"flow_per_section": 55,
            "season_melt_multiplier": {"spring":1.0,"summer":1.4,"autumn":0.85,"winter":0.45},
            "season_flow_bonus": {"winter": -3}},
          "population": {"daily_consumption": {"water_per_person":3.0,"food_per_person":3}},
          "resources": {
            "water": {"initial": {"current":90,"capacity":300,"flow_per_day":5}},
            "food": {"initial": {"naan":40,"grain":30,"meat":8}},
            "materials": {"initial": {"wood":30,"earth":50,"tools":4}},
            "silver": {"initial": 40}
          }
        }
        """);

        private static double Num(JsonNode node, double fallback)
        {
            if (node is JsonValue v && v.TryGetValue<double>(out var d)) return d;
            return fallback;
        }

        private static JsonObject InitialState(JsonNode n)
        {
            var resCfg = n?["resources"];
            var foodCfg = resCfg?["food"]?["initial"];
            var matCfg = resCfg?["materials"]?["initial"];
            var waterCfg = resCfg?["water"]?["initial"];

            var characters = new JsonObject();
            foreach (var id in CharacterIds)
                characters[id] = new JsonObject
                {
                    ["affinity"] = 0.0,
                    ["mood"] = 60.0,
                    ["memory"] = new JsonArray(),
                };

            return new JsonObject
            {
                ["calendar"] = new JsonObject
                {
                    ["day"] = 1, ["season"] = "spring", ["phase"] = "morning",
                },
                ["karez"] = new JsonObject
                {
                    ["sections"] = 0, ["flow_per_day"] = 0.0,
                },
                ["resources"] = new JsonObject
                {
                    ["water"] = new JsonObject
                    {
                        ["current"] = Num(waterCfg?["current"], 90),
                        ["capacity"] = Num(waterCfg?["capacity"], 300),
                        // 旱季残存渗流，计入每日入账，不是库存。
                        ["base_flow"] = Num(waterCfg?["flow_per_day"], 5),
                    },
                    ["food"] = new JsonObject
                    {
                        ["naan"] = Num(foodCfg?["naan"], 40),
                        ["grain"] = Num(foodCfg?["grain"], 30),
                        ["fruit"] = Num(foodCfg?["fruit"], 0),
                        ["meat"] = Num(foodCfg?["meat"], 8),
                        ["milk"] = Num(foodCfg?["milk"], 0),
                    },
                    ["materials"] = new JsonObject
                    {
                        ["wood"] = Num(matCfg?["wood"], 30),
                        ["earth"] = Num(matCfg?["earth"], 50),
                        ["cloth"] = Num(matCfg?["cloth"], 5),
                        ["tools"] = Num(matCfg?["tools"], 4),
                    },
                    ["silver"] = Num(resCfg?["silver"]?["initial"], 40),
                },
                ["population"] = 6,
                ["stats"] = new JsonObject
                {
                    ["prosperity"] = 5.0, ["reputation"] = 10.0,
                    ["morale"] = 55.0, ["security"] = 40.0,
                },
                ["characters"] = characters,
                ["flags"] = new JsonObject(),
            };
        }

        public int Day => (int)Num(State["calendar"]?["day"], 1);
        public string Season => State["calendar"]?["season"]?.GetValue<string>() ?? "spring";

        // -------------------------------------------------------------------
        // 与 Python 服务通信
        // -------------------------------------------------------------------

        /// <summary>
        /// 发一次叙事请求并应用结果。永不抛异常 —— 失败会返回 Degraded=true 的结果。
        /// </summary>
        public async Task<NarrateResult> NarrateAsync(
            string playerInput, string characterId = null, IEnumerable<string> recent = null)
        {
            var speaker = string.IsNullOrEmpty(characterId) ? "lao_kanjiang" : characterId;

            if (OfflineMode)
                return Degraded(speaker, "OfflineMode 已开启");

            var payload = new JsonObject
            {
                ["schema_version"] = SchemaVersion,
                ["scene"] = "karez_work",
                ["player_input"] = playerInput,
                ["character_id"] = speaker,
                ["context"] = BuildContextForAi(speaker),
                ["memory"] = new JsonArray(GetMemory(speaker).Select(m => JsonValue.Create(m)).ToArray()),
                ["recent"] = new JsonArray((recent ?? Array.Empty<string>())
                    .Select(r => JsonValue.Create(r)).ToArray()),
            };

            var started = DateTime.UtcNow;
            try
            {
                using var content = new StringContent(payload.ToJsonString(), Encoding.UTF8, "application/json");
                using var resp = await _http.PostAsync(_endpoint, content);
                var elapsed = (DateTime.UtcNow - started).TotalMilliseconds;

                if (!resp.IsSuccessStatusCode)
                    return Degraded(speaker, $"HTTP {(int)resp.StatusCode}");

                var text = await resp.Content.ReadAsStringAsync();
                var parsed = JsonNode.Parse(text) as JsonObject;
                if (parsed == null)
                    return Degraded(speaker, "返回的不是 JSON 对象");

                var result = new NarrateResult
                {
                    Narration = parsed["narration"]?.GetValue<string>() ?? "",
                    Speaker = parsed["speaker"]?.GetValue<string>() ?? speaker,
                    Emotion = parsed["emotion"]?.GetValue<string>() ?? "",
                    LatencyMs = elapsed,
                };

                var meta = parsed["meta"] as JsonObject;
                result.Mode = meta?["mode"]?.GetValue<string>() ?? "live";
                result.TokensIn = (int)Num(meta?["tokens_in"], 0);
                result.TokensOut = (int)Num(meta?["tokens_out"], 0);
                result.CacheHitTokens = (int)Num(meta?["cache_hit_tokens"], 0);
                result.Degraded = result.Mode == "demo";
                LastRequestDegraded = result.Degraded;

                result.Deltas = ExtractDeltas(parsed["state_delta"]);
                foreach (var m in parsed["memory_append"] as JsonArray ?? new JsonArray())
                    if (m != null) result.MemoryAppend.Add(m.GetValue<string>());
                foreach (var s in parsed["suggestions"] as JsonArray ?? new JsonArray())
                    if (s != null) result.Suggestions.Add(s.GetValue<string>());

                ApplyDeltas(result.Deltas);
                foreach (var m in result.MemoryAppend) AddMemory(speaker, m);
                ClampAll();

                return result;
            }
            catch (TaskCanceledException)
            {
                return Degraded(speaker, "请求超时");
            }
            catch (HttpRequestException ex)
            {
                return Degraded(speaker, $"网络错误: {ex.Message}");
            }
            catch (JsonException ex)
            {
                return Degraded(speaker, $"JSON 解析错误: {ex.Message}");
            }
            catch (Exception ex)
            {
                return Degraded(speaker, $"未预期错误: {ex.GetType().Name}");
            }
        }

        private NarrateResult Degraded(string speaker, string reason)
        {
            LastRequestDegraded = true;
            var fallback = Fallback.Line(speaker);
            return new NarrateResult
            {
                Narration = fallback,
                Speaker = speaker,
                Degraded = true,
                Mode = "demo",
                Reason = reason,
                Suggestions = Fallback.Suggestions(),
            };
        }

        // -------------------------------------------------------------------
        // delta 门禁
        // -------------------------------------------------------------------

        private List<Delta> ExtractDeltas(JsonNode raw)
        {
            var clean = new List<Delta>();
            if (raw is not JsonArray arr) return clean;

            foreach (var item in arr)
            {
                if (item is not JsonObject obj) continue;
                var op = obj["op"]?.GetValue<string>() ?? "";
                var path = obj["path"]?.GetValue<string>() ?? "";

                if (op is not ("add" or "sub" or "set" or "mul")) continue;
                if (!PathAllowed(path)) continue;
                if (obj["value"] is not JsonValue v || !v.TryGetValue<double>(out var value)) continue;
                if (double.IsNaN(value) || double.IsInfinity(value)) continue;

                clean.Add(new Delta
                {
                    Op = op,
                    Path = path,
                    Value = Math.Clamp(value, -MaxDeltaMagnitude, MaxDeltaMagnitude),
                });
            }
            return clean;
        }

        private static bool PathAllowed(string path) =>
            !string.IsNullOrEmpty(path) && AllowedPrefixes.Any(path.StartsWith);

        /// <summary>应用一批已经过门的 delta，返回成功条数。</summary>
        public int ApplyDeltas(IEnumerable<Delta> deltas)
        {
            var applied = 0;
            foreach (var d in deltas)
                if (SetPath(d.Path, d.Op, d.Value)) applied++;
            return applied;
        }

        private bool SetPath(string path, string op, double value)
        {
            var parts = path.Split('.');
            if (parts.Length < 2) return false;

            if (parts[0] == "characters")
            {
                if (parts.Length != 3) return false;
                var chars = State["characters"]!.AsObject();
                if (chars[parts[1]] is not JsonObject entry)
                {
                    entry = new JsonObject { ["affinity"] = 0.0, ["mood"] = 60.0, ["memory"] = new JsonArray() };
                    chars[parts[1]] = entry;
                }
                entry[parts[2]] = ApplyOp(Num(entry[parts[2]], 0), op, value);
                return true;
            }

            JsonObject cursor = State;
            for (var i = 0; i < parts.Length - 1; i++)
            {
                if (cursor[parts[i]] is not JsonObject next)
                {
                    next = new JsonObject();
                    cursor[parts[i]] = next;
                }
                cursor = next;
            }
            var leaf = parts[^1];
            cursor[leaf] = ApplyOp(Num(cursor[leaf], 0), op, value);
            return true;
        }

        private static double ApplyOp(double current, string op, double value) => op switch
        {
            "add" => current + value,
            "sub" => current - value,
            "mul" => current * value,
            "set" => value,
            _ => current,
        };

        /// <summary>客户端侧夹紧 —— 契约要求的第二道闸门。</summary>
        public void ClampAll()
        {
            var res = State["resources"]!.AsObject();
            var water = res["water"]!.AsObject();
            water["current"] = Math.Clamp(Num(water["current"], 0), 0, Num(water["capacity"], 300));
            res["silver"] = Math.Max(0, Num(res["silver"], 0));

            var stats = State["stats"]!.AsObject();
            foreach (var key in new[] { "prosperity", "reputation", "morale", "security" })
                stats[key] = Math.Clamp(Num(stats[key], 0), 0, 100);

            foreach (var (_, node) in State["characters"]!.AsObject())
            {
                if (node is not JsonObject c) continue;
                c["affinity"] = Math.Clamp(Num(c["affinity"], 0), -100, 100);
                c["mood"] = Math.Clamp(Num(c["mood"], 60), 0, 100);
            }

            State["population"] = Math.Max(0, (int)Num(State["population"], 0));
            foreach (var kind in new[] { "food", "materials" })
                if (res[kind] is JsonObject bag)
                    foreach (var key in bag.Select(kv => kv.Key).ToList())
                        bag[key] = Math.Max(0, Num(bag[key], 0));
        }

        // -------------------------------------------------------------------
        // 记忆
        // -------------------------------------------------------------------

        public List<string> GetMemory(string characterId)
        {
            var mem = State["characters"]?[characterId]?["memory"] as JsonArray;
            if (mem == null) return new List<string>();
            return mem.Skip(Math.Max(0, mem.Count - 8))
                      .Select(m => m?.GetValue<string>() ?? "")
                      .Where(s => s.Length > 0)
                      .ToList();
        }

        public void AddMemory(string characterId, string text)
        {
            var chars = State["characters"]!.AsObject();
            if (chars[characterId] is not JsonObject entry)
            {
                entry = new JsonObject { ["affinity"] = 0.0, ["mood"] = 60.0, ["memory"] = new JsonArray() };
                chars[characterId] = entry;
            }
            var mem = entry["memory"] as JsonArray ?? new JsonArray();
            mem.Add($"[第{Day}天] {text}");
            while (mem.Count > 200) mem.RemoveAt(0);
            entry["memory"] = mem;
        }

        public JsonObject BuildContextForAi(string speaker = null)
        {
            var ctx = new JsonObject
            {
                ["day"] = Day,
                ["season"] = Season,
                ["resources"] = new JsonObject
                {
                    ["water"] = Num(State["resources"]?["water"]?["current"], 0),
                    ["water_capacity"] = Num(State["resources"]?["water"]?["capacity"], 0),
                    ["silver"] = Num(State["resources"]?["silver"], 0),
                    ["food"] = State["resources"]?["food"]?.DeepClone(),
                },
                ["karez"] = new JsonObject
                {
                    ["sections"] = (int)Num(State["karez"]?["sections"], 0),
                    ["flow_per_day"] = Num(State["karez"]?["flow_per_day"], 0),
                },
                ["population"] = (int)Num(State["population"], 0),
                ["stats"] = State["stats"]?.DeepClone(),
            };
            if (!string.IsNullOrEmpty(speaker) && State["characters"]?[speaker] != null)
                ctx["speaker_affinity"] = Num(State["characters"]![speaker]!["affinity"], 0);
            return ctx;
        }

        // -------------------------------------------------------------------
        // 时间推进
        // -------------------------------------------------------------------

        public void AdvanceDay()
        {
            var karezCfg = _numbers?["karez"];
            var sections = (int)Num(State["karez"]?["sections"], 0);
            var melt = Num(karezCfg?["season_melt_multiplier"]?[Season], 1.0);
            var baseFlow = Num(State["resources"]?["water"]?["base_flow"], 5);
            // 季节性的基础渗流修正（冬季为负），融水倍率只作用于竖井出水与残流。
            var bonus = karezCfg?["season_flow_bonus"]?[Season] != null
                ? Num(karezCfg["season_flow_bonus"][Season], 0)
                : 0;
            var flow = (sections * Num(karezCfg?["flow_per_section"], 55) + baseFlow) * melt + bonus;

            var popCfg = _numbers?["population"]?["daily_consumption"];
            var pop = (int)Num(State["population"], 0);
            var waterNeed = pop * Num(popCfg?["water_per_person"], 3.0);
            var foodNeed = (int)(pop * Num(popCfg?["food_per_person"], 3));

            var res = State["resources"]!.AsObject();
            var water = res["water"]!.AsObject();
            State["karez"]!["flow_per_day"] = flow;
            water["current"] = Math.Clamp(
                Num(water["current"], 0) + flow - waterNeed, 0, Num(water["capacity"], 300));

            ConsumeFood(foodNeed);

            if (Num(water["current"], 0) <= 0)
                State["stats"]!["morale"] = Math.Max(0, Num(State["stats"]!["morale"], 0) - 3);

            State["calendar"]!["day"] = Day + 1;
            RollSeason();
            ClampAll();
        }

        private void ConsumeFood(int amount)
        {
            var food = State["resources"]!["food"]!.AsObject();
            var remaining = amount;
            foreach (var key in new[] { "naan", "grain", "fruit", "meat", "milk" })
            {
                if (remaining <= 0) break;
                var have = (int)Num(food[key], 0);
                var take = Math.Min(have, remaining);
                food[key] = have - take;
                remaining -= take;
            }
            if (remaining > 0)
                State["stats"]!["morale"] = Math.Max(0, Num(State["stats"]!["morale"], 0) - 5);
        }

        private void RollSeason()
        {
            var perSeason = (int)Num(_numbers?["calendar"]?["days_per_season"], 30);
            if (perSeason <= 0) return;
            var seasons = (_numbers?["calendar"]?["seasons"] as JsonArray)?
                .Select(s => s!.GetValue<string>()).ToArray()
                ?? new[] { "spring", "summer", "autumn", "winter" };
            State["calendar"]!["season"] = seasons[((Day - 1) / perSeason) % seasons.Length];
        }

        // -------------------------------------------------------------------
        // 存档
        // -------------------------------------------------------------------

        public bool Save(string path)
        {
            try
            {
                var wrapper = new JsonObject
                {
                    ["save_version"] = 1,
                    ["seed"] = 0,
                    ["state"] = State.DeepClone(),
                };
                File.WriteAllText(path, wrapper.ToJsonString(new JsonSerializerOptions { WriteIndented = true }),
                    Encoding.UTF8);
                return true;
            }
            catch (IOException ex)
            {
                GD.PushError($"存档失败 {path}: {ex.Message}");
                return false;
            }
        }

        public bool Load(string path)
        {
            if (!File.Exists(path)) return false;
            try
            {
                var wrapper = JsonNode.Parse(File.ReadAllText(path, Encoding.UTF8)) as JsonObject;
                if (wrapper?["state"] is not JsonObject saved) return false;
                State = saved;
                ClampAll();
                return true;
            }
            catch (JsonException ex)
            {
                GD.PushError($"读档失败 {path}: {ex.Message}");
                return false;
            }
        }
    }

    /// <summary>
    /// 离线兜底台词。必须与 Python 侧 ai/demo.py 保持一致 —— 两处任何一处改动都要同步。
    /// 内容要求：符合人设、不推进剧情、不带承诺（避免污染记忆系统）、不改任何数值。
    /// </summary>
    public static class Fallback
    {
        private static readonly Dictionary<string, string[]> Lines = new()
        {
            ["lao_kanjiang"] = new[]
            {
                "（他蹲在井口，捻起一把土在指间搓开）……土是干的。你等我想想。",
                "（他哼了一声，没抬头）你先别急着挖。让我看看这井壁。",
                "水不是喊出来的。你要么等，要么下去看看。",
            },
            ["muqam_yiren"] = new[]
            {
                "（他拨了两下弦，又停下）哎，今天嗓子不行，改天给你弹。",
                "你这话说得像没调的歌。……先说别的，让我缓缓。",
                "（他望着远处）这事啊，我在别处听过另一个说法，可不一定对。",
            },
            ["hasake_qishou"] = new[]
            {
                "（他把马鞭往腰带上一插）骑马去，两天就到。——不过得看天气。",
                "这个我能行。……你别这么看我，我真能行。",
                "你们这儿的人都蹲在墙里，不难受吗？",
            },
            ["hanshang_zhanggui"] = new[]
            {
                "（他摸了摸算袋，没说话）……账要算清，情分才长久。先看看货。",
                "这个价，我不能做。你要是愿意，我们坐下慢慢谈。",
                "我走这条道三十年，什么没见过。——话别说满，先看天色。",
            },
            ["chuniang"] = new[]
            {
                "（她把手在围裙上擦了擦）先吃饭，饿着肚子说什么都白搭。",
                "哎哟，你瘦了。……行了行了，锅里还有，自己盛去。",
                "这事儿我不管——（她顿了一下）你先去把柴抱进来。",
            },
            ["shenmi_lvren"] = new[]
            {
                "（他没有立刻回答，手指在书箱边缘敲了两下）……未必。",
                "我见过类似的事。在别处。",
                "这要看你问的是哪一个。",
            },
            ["mafei_toumu"] = new[]
            {
                "（他上下打量你，没说话，手按在刀柄上）……你可以不给。",
                "我不喜欢走两趟。你最好想清楚。",
                "（他忽然笑了一下）你是个明白人。",
            },
        };

        private static readonly string[] Generic =
        {
            "（对方沉默了一下，似乎在斟酌）……今天先这样吧。",
            "（他看了看天色）天不早了，这事回头再说。",
            "（对方没有接话，只是点了点头）",
        };

        public static string Line(string characterId)
        {
            if (!string.IsNullOrEmpty(characterId) && Lines.TryGetValue(characterId, out var pool))
                return pool[Random.Shared.Next(pool.Length)];
            return Generic[Random.Shared.Next(Generic.Length)];
        }

        public static List<string> Suggestions() => new() { "继续", "换个话题", "先等等" };
    }
}
