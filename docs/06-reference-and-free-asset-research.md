# 《坎儿井》美术资料调研报告

**任务一：参考图来源（只作美术参考，不可直接使用）**
**任务二：可商用免费素材源（用于实际制作）**

调研日期：2026-10-05
调研方式：实际调用搜索工具（引擎 exa / tavily / keenable / parallel / bing / anysearch + 直接 HTTP 抓取）逐条核验 URL。

---

## 0. 核查方法与本次的可验证性边界（请先读这一节）

### 0.1 搜索工具实际情况

- **本次可用**：exa、tavily、keenable、parallel、bing、anysearch、deepseek-official
- **本次不可用**：firecrawl（IP 被拒 403）、perplexity / serpbase / you / baidu / kimi / aliyun / doubao（未配置 API Key）、ddg / ddg-lite（连接失败）、searxng（全部实例超时）

### 0.2 重要限制：以下站点本机无法直连抓取

`commons.wikimedia.org`、`*.wikipedia.org`、`api.wikimedia.org`、`github.com`、`metmuseum.org`、`whc.unesco.org`、`si.edu`、`itch.io`、`pixabay.com`、`sonniss.com`（Cloudflare 403）。

上述来源的 URL 均通过 **exa 实时索引**核验（返回当前页面标题 + 摘要 + 索引更新时间，证明页面在线），但**没有打开页面本身**。因此：

> **Commons 每个文件页上的具体协议、以及博物馆页面的具体条款，落地使用前必须人工打开确认一次。** 本报告不代替那一步。

### 0.3 已实际打开并读取内容（HTTP 200）的站点

`kenney.nl/support`、`freesound.org/help/faq`、`craftpix.net/file-licenses`、`mixkit.co/license/modal/sfxFree`、`hyperos.mi.com/font/zh/faq`、`ark-pixel-font.takwolf.com`、`fusion-pixel-font.takwolf.com`、`www.zcool.com.cn/special/zcoolfonts`、`fonts.alibabagroup.com`、`www.zapsplat.com/license-type/standard-license/`、`sound-effects.bbcrewind.co.uk/licensing`、`pixabay.com`（403，改用索引核验）。

### 0.4 一个通用规则（务必记住）

**Wikimedia Commons 的分类页本身不授予任何许可。** 许可在每一个**文件页**上单独标注（CC0 / CC BY 4.0 / CC BY-SA 4.0 / 公有领域 等）。本报告给出的分类页用于「找到图」，用图前必须点进具体文件页看协议。

---

# 任务一：参考图来源

## 1.0 三个通用高价值入口（先收藏这三个）

| 来源 | URL | 授权说明 |
|---|---|---|
| Wikimedia Commons | https://commons.wikimedia.org | 每个文件页单独标注协议，主流为 CC BY-SA 4.0 / CC BY 4.0 / CC0 / 公有领域。分类页只负责聚合，不授权 |
| Openverse（CC 官方推荐聚合器） | https://openverse.org | 聚合 8 亿+ 开放授权图像与音频，可按「CC0 / CC BY / 允许商用」过滤。适合批量筛可商用图 |
| The Met Open Access | https://www.metmuseum.org/openaccess | 49.2 万张公有领域作品图像，**CC0，免费且无限制使用，含商用** |

---

## 1.1 坎儿井（竖井井口 / 暗渠 / 明渠 / 涝坝）

| 来源 | URL | 授权说明 |
|---|---|---|
| Commons 分类：Turpan karez system | https://commons.wikimedia.org/wiki/Category:Turpan_karez_system | 吐鲁番坎儿井博物馆实景、沙盘剖面照片。逐文件看协议 |
| Commons 分类：Qanat | https://commons.wikimedia.org/wiki/Category:Qanat | 坎儿井/坎纳特通类，含竖井口阵列、地下渠道剖面，是「暗渠」最好的形制参考 |
| Commons 文件 | https://commons.wikimedia.org/wiki/File:Turpan-karez-museo-d02.jpg | 坎儿井博物馆照片，逐文件看协议 |
| 吐鲁番市政府《吐鲁番坎儿井探秘》 | https://www.tlf.gov.cn/tlfs/c106440/202211/72d8f3e5e8824ee2912ebda5bedc4539.shtml | 官方文旅资料。文字明确「竖井、暗渠、明渠、涝坝」四部分构成 + 竖井深 1~120m 数据。**页面图片未开放再发布授权，仅可阅读参考** |
| 吐鲁番市政府《坎儿井：吐鲁番大地的生命之源》 | https://www.tlf.gov.cn/tlfs/c106440/202403/c2a1a7af97eb428c857a3c4e12fb562a.shtml | 同上，官方公开可查看 |
| 国家级非遗「坎儿井开凿技艺」 | https://www.ihchina.cn/project_details/14761.html | 中国非物质文化遗产网官方项目页，项目序号 1350。文本资料可引用 |
| 最高检报道（含井下实景描述） | https://www.spp.gov.cn/spp/zdgz/202510/t20251021_709057.shtml | 官方公开，写明 2006 年列为全国重点文物保护单位 |

**美术要点**：竖井口在地表是一串等距土环（强烈建议做成像素 tile 的「点阵节奏」）；暗渠为窄高拱形土洞；涝坝是小型蓄水池，水面反光可与绿洲共用色板。

---

## 1.2 交河故城 / 高昌故城（生土建筑遗址）

| 来源 | URL | 授权说明 |
|---|---|---|
| Commons 分类：Jiaohe ruins | https://commons.wikimedia.org/wiki/Category:Jiaohe_ruins | 交河故城（雅尔湖），含 2 个子类、216 个文件。逐文件看协议 |
| Commons 分类：Gaochang ruins | https://commons.wikimedia.org/wiki/Category:Gaochang_ruins | 高昌故城，122 个文件。逐文件看协议 |
| Commons 文件（交河） | https://commons.wikimedia.org/wiki/File:Jiaohe_City(Yarkhoto),Turpan,Xinjiang_HY4.jpg | 遗址实景 |
| Commons 文件（交河＋绿洲关系） | https://commons.wikimedia.org/wiki/File:Turpan-jiaohe-oasis-lateral-d01.jpg | 台地遗址与周边绿洲的空间关系，做横版背景很有用 |
| 丝绸之路申遗官网 · 交河故城 | http://www.silkroads.org.cn/portal.php?aid=718&mod=view | 官方遗产介绍，含唐代安西都护府沿革 |
| 丝绸之路申遗官网 · 高昌故城 | http://www.silkroads.org.cn/portal.php?aid=4962&mod=view | 官方遗产介绍 |
| UNESCO 世界遗产「丝绸之路：长安—天山廊道的路网」 | https://whc.unesco.org/en/list/1442/ | 交河故城、高昌故城均为其中遗址点，2014 年列入 |
| 新华网《时光"雕刻"出的城市——走进交河故城》 | http://xj.xinhuanet.com/20240409/902b99bc331644a691374550e6c26749/c.html | 官方媒体，含「世界上保存最完整、延续时间最长、最古老的生土结构古代城市建筑群」定性 |

**美术要点**：生土建筑 = 无砖石、夯土/掏挖成形、洞口多为倒梯形；遗址是「减法建筑」（从台地掏出来的），像素表现应是层叠高差与密集院墙，而不是独立房子。

---

## 1.3 葡萄晾房（镂空花格墙）

| 来源 | URL | 授权说明 |
|---|---|---|
| Commons 分类：Chunche（吐鲁番晾房专名） | https://commons.wikimedia.org/wiki/Category:Chunche | 定义即为「吐鲁番特有的葡萄晾干房」，最精准的一类。逐文件看协议 |
| Commons 文件 | https://commons.wikimedia.org/wiki/File:Chunche.jpg | 晾房外观 |
| Commons 分类：Grape Valley | https://commons.wikimedia.org/wiki/Category:Grape_Valley | 葡萄沟，晾房+绿洲组合场景 |
| 维基百科 Chunche 条目 | https://en.wikipedia.org/wiki/Chunche | 含「晾房内悬挂葡萄晾晒」照片，室内结构参考 |
| 中国驻欧盟使团·吐鲁番葡萄地理标志 | http://eu.china-mission.gov.cn/eng/zgggfz/cega/202112/t20211203_10462023.htm | 官方资料，葡萄沟产季与品种信息 |

**美术要点**：花格墙是**通风孔洞构成的重复几何纹样**，最适合做成 2~3 个可复用像素 tile 叠加出远近层次；土黄色砖体 + 深色孔洞即可读出形制。

---

## 1.4 哈萨克毡房

| 来源 | URL | 授权说明 |
|---|---|---|
| Commons 分类：Kazakh yurts | https://commons.wikimedia.org/wiki/Category:Kazakh_yurts | 39 个文件，2026-02 仍有更新。逐文件看协议 |
| Commons 分类：Yurts | https://commons.wikimedia.org/wiki/Category:Yurts | 上级分类，含内部结构与搭建过程 |
| Commons 文件（外观） | https://commons.wikimedia.org/wiki/File:Kazakh_Yurts.jpg | 毡房外观 |
| Commons 文件（内部） | https://commons.wikimedia.org/wiki/File:SB_-_Inside_a_Kazakh_yurt.jpg | 内部木格栅（kerege）与毡顶结构，做室内场景必备 |

**风险提醒**：Commons 上大量 "yurt" 照片实为蒙古包或吉尔吉斯毡房，形制与哈萨克毡房有差别（顶圈、门朝向、装饰）。**取图前务必核对拍摄地**。

---

## 1.5 艾德莱斯绸（Atlas / Etles / Ikat 纹样）

| 来源 | URL | 授权说明 |
|---|---|---|
| Commons 分类：Atlas silk | https://commons.wikimedia.org/wiki/Category:Atlas_silk | 含 Atlas Silk Factory 相关 29 个文件。逐文件看协议 |
| Commons 分类：Adras (fabric) | https://commons.wikimedia.org/wiki/Category:Adras_(fabric) | Adras 为半丝半棉同类织物 |
| 维基百科 Etles silk 条目 | https://en.wikipedia.org/wiki/Etles_silk | 艾德莱斯绸（维吾尔/乌兹别克 Ikat）通识与工艺说明 |
| 学术：新疆维吾尔族传统 Atlas 织物特征 | https://www.koreascience.kr/article/JAKO202013965594509.page | 纹样分类与跨地域 Ikat 对比，做纹样设计时的分类依据 |
| UNESCO ICH 图集（atlas/adras） | https://ich.unesco.org/en/photo-pop-up-00973?photoID=12929 | **注意：这是塔吉克斯坦的项目**（2023 年列入），不是新疆项目 |

> **地域风险（必须注意）**：Commons 与 Openverse 上可商用的 atlas/ikat 织物照片，绝大多数拍摄于**乌兹别克斯坦（马尔吉兰）与塔吉克斯坦**。把它们标注为「新疆艾德莱斯」会造成误导。若必须新疆产地，应优先找明确拍摄于和田/洛浦的图；否则**用 AI 生成纹样并标注为再创作**，不要冒用地域。

---

## 1.6 维吾尔族花帽（朵帕 / Doppa）

| 来源 | URL | 授权说明 |
|---|---|---|
| Commons 分类：Doppis | https://commons.wikimedia.org/wiki/Category:Doppis | 朵帕专类，含维吾尔与乌兹别克。逐文件看协议 |
| Commons 文件（制作过程） | https://commons.wikimedia.org/wiki/File:Uyghur-Dopa-Maker.jpg | 花帽手工艺人，做 NPC 与工坊场景参考 |
| V&A 博物馆藏品：doppa 花帽 | https://collections.vam.ac.uk/item/O24336/doppa-skull-cap-unknown/ | 博物馆官网公开可查看。**V&A 图片授权**：Explore the Collections 内容限非商业用途，见 https://www.vam.ac.uk/info/va-websites-terms-conditions ；商业授权走 https://www.vandaimages.com/ |
| Commons 分类：Uyghur culture | https://commons.wikimedia.org/wiki/Category:Uyghur_culture | 服饰、节庆等广义文化图 |
| Commons 文件（传统服饰整体） | https://commons.wikimedia.org/wiki/File:Uyghur-man-at-Kashgar-Sunday-Market.jpg | 花帽在整体穿搭中的比例与位置 |

**美术要点**：男帽多为**四棱方形**（四角有棱、白地黑线刺绣），女帽偏圆、色彩更艳。像素化时抓「方形轮廓 + 白底黑几何刺绣」两个特征即可辨识。

---

## 1.7 民族乐器（热瓦普 / 都塔尔 / 冬不拉 / 手鼓）

| 来源 | URL | 授权说明 |
|---|---|---|
| Commons 分类：Uyghur musical instruments | https://commons.wikimedia.org/wiki/Category:Uyghur_musical_instruments | 维吾尔乐器总类（2024-05 更新）。逐文件看协议 |
| Commons 分类：Rawap（热瓦普） | https://commons.wikimedia.org/wiki/Category:Rawap | 含子分类 |
| Commons 文件：Rawap.jpg | https://commons.wikimedia.org/wiki/File:Rawap.jpg | 文件页自述为 **Creative Commons 授权**（作者 Jo Dusepo） |
| Commons 分类：Dutâr（都塔尔） | https://commons.wikimedia.org/wiki/Category:Dut%C3%A2r | 长颈二弦琴 |
| Commons 文件：Dutar suraty.jpg | https://commons.wikimedia.org/wiki/File:Dutar_suraty.jpg | 都塔尔实物 |
| Commons 分类：Dombra（冬不拉） | https://commons.wikimedia.org/wiki/Category:Dombra | 哈萨克冬不拉 |
| Commons 分类：Frame drums（手鼓，需人工筛选） | https://commons.wikimedia.org/wiki/Category:Frame_drums | **未找到以「维吾尔族手鼓 dap」为主题的独立 Commons 分类**，只能从此类中人工筛选，或参考下方 Met 藏品 |
| Met 博物馆藏品：Frame Drum (Chinese Uighyur) | https://www.metmuseum.org/art/collection/search/504461 | Met Open Access，**CC0 可商用** |
| Hartenberger 世界乐器收藏：Uyghur 'Rawap' | https://wmic.net/uyghur-rawap/ | 私人收藏站，**未找到明确授权说明，仅作形制比对，不可下载使用** |
| Hartenberger 世界乐器收藏：Uyghur 'Dap' (Daire) | https://wmic.net/uyghur-dap-daire/ | 同上，手鼓形制的图文说明很有用 |

**美术要点**：热瓦普＝瓢形音箱+弯颈+羊皮蒙面；都塔尔＝细长梨形+极长琴颈；冬不拉＝细长琴身+品丝；手鼓（dap/daire）＝圆框单面蒙皮+框内小铁环。四者轮廓差异足够大，像素图标可一眼区分。

---

## 1.8 地貌（雅丹 / 火焰山 / 沙漠 / 绿洲）

| 来源 | URL | 授权说明 |
|---|---|---|
| Commons 分类：Flaming Mountains（火焰山） | https://commons.wikimedia.org/wiki/Category:Flaming_Mountains | 2026-08 更新，红色砂岩侵蚀地貌。逐文件看协议 |
| Commons 图库页：Flaming Mountains | https://commons.wikimedia.org/wiki/Flaming_Mountains | 精选图集 |
| Commons 文件 | https://commons.wikimedia.org/wiki/File:Turpan-flaming-mountains-d02.jpg | 火焰山近景（伯孜克里克石窟附近） |
| Commons 分类：Taklamakan（塔克拉玛干） | https://commons.wikimedia.org/wiki/Category:Taklamakan | 2025-10 更新 |
| Commons 分类：Kumtag Desert (Turpan)（库木塔格，鄯善） | https://commons.wikimedia.org/wiki/Category:Kumtag_Desert_(Turpan) | **就在吐鲁番境内**，沙丘纹理最贴近本项目 |
| Commons 分类：Yardangs（雅丹） | https://commons.wikimedia.org/wiki/Category:Yardangs | 雅丹地貌总类 |
| Commons 分类：Dunhuang Yardang National Geopark | https://commons.wikimedia.org/wiki/Category:Dunhuang_Yardang_National_Geopark | 图多质优，但**在甘肃敦煌**，形制可参考、地域需注意 |
| Commons 文件：Yardangs in the Tsaidam Desert | https://commons.wikimedia.org/wiki/File:Yardangs_in_the_Tsaidam_Desert.jpg | 柴达木雅丹，同上 |
| Commons 分类：Turpan Depression | https://commons.wikimedia.org/wiki/Category:Turpan_Depression | 吐鲁番盆地整体地貌 |

**像素配色建议**：火焰山红砂岩主色约 `#8C3B24`，配沙黄 `#D9B26A`；沙漠用 3~4 阶明度渐变的暖沙色；绿洲是**高饱和窄色带**（深绿→黄绿→浅黄），与四周荒漠形成硬边界——这是「绿洲驿站」题材最强的一张视觉牌。

---

## 1.9 唐代西域文物（陶器 / 铜器 / 织物）

### 可商用（CC0，最优先）

| 来源 | URL | 授权说明 |
|---|---|---|
| The Met Open Access 政策页 | https://www.metmuseum.org/openaccess | 49.2 万张公有领域图像 **CC0，含商用，无限制** |
| Met：Textile with Pearl Roundels with Dragons | https://www.metmuseum.org/art/collection/search/40108 | 中国或中亚，联珠纹，唐代代表性纹样 → **CC0** |
| Met：Textile with Processions of Rams | https://www.metmuseum.org/art/collection/search/72707 | 产地含「中国新疆」选项，丝路织物 → **CC0** |
| Met：Textile with floral medallions（唐） | https://www.metmuseum.org/art/collection/search/52098 | 唐代团花织物 → **CC0** |
| Met：Tapestry with Dragons and Flowers | https://www.metmuseum.org/art/collection/search/39733 | 东中亚丝织 → **CC0** |
| Met：When Silk Was Gold 图录 | https://www.metmuseum.org/met-publications/when-silk-was-gold-central-asian-and-chinese-textiles | 中亚与中国奢侈品丝织专论，图案断代依据 |

### 仅可查看（官方公开，未开放图片授权）

| 来源 | URL | 授权说明 |
|---|---|---|
| Commons 分类：Art of the Tang Dynasty | https://commons.wikimedia.org/wiki/Category:Art_of_the_Tang_Dynasty | 含 Textiles of the Tang Dynasty 子类。逐文件看协议 |
| Commons 分类：Ceramics of the Tang Dynasty | https://commons.wikimedia.org/wiki/Category:Ceramics_of_the_Tang_Dynasty | 唐代陶瓷 |
| Commons 分类：Sancai ceramics of the Tang Dynasty | https://commons.wikimedia.org/wiki/Category:Sancai_ceramics_of_the_Tang_Dynasty | 唐三彩（洛阳/陕西历史博物馆藏） |
| Commons 分类：Art of Xinjiang | https://commons.wikimedia.org/wiki/Category:Art_of_Xinjiang | 新疆艺术文物 |
| 中国国家博物馆「交融汇聚——新疆精品历史文物展」 | https://www.chnmuseum.cn/portals/0/web/zt/202306jrhj/ | 官方展览页，含新疆精品文物。**未开放图片授权，仅可查看** |
| 新疆维吾尔自治区博物馆（自治区文旅厅机构页） | https://wlt.xinjiang.gov.cn/wlt/jgzn/202412/5dde59aa445a4fc0937af923da432b5b.shtml | 官方，馆藏介绍 |
| 香港文物探知馆 唐代展（阿斯塔那出土织物） | https://www.amo.gov.hk/en/visitor-centre/exhibitions/heritage-discovery-centre/tang-exhibition/ag22/index.html | 政府官网，明确注明藏品出土地为**吐鲁番阿斯塔那墓地**、藏于新疆博物馆。仅可查看 |

### 非商业可用（若本项目要商用则不可直接使用图）

| 来源 | URL | 授权说明 |
|---|---|---|
| 大英博物馆 版权与许可 | https://www.britishmuseum.org/terms-use/copyright-and-permissions | 多数 © Trustees 图片采用 **CC BY-NC-SA 4.0（禁止商用）** |
| 大英博物馆图片库（付费商业授权） | https://www.bmimages.com/ | 商业用途需购买授权 |

---

# 任务二：可商用免费素材源

## 2.0 平台速查表

| 平台 | 类型 | 授权模式 | 可商用 | 本项目判断 |
|---|---|---|---|---|
| Kenney | 像素/2D/3D/音频 | **CC0** | 是，无需署名 | **首选**，最安全 |
| OpenGameArt | 综合 | 逐素材：CC0 / CC BY / CC BY-SA / GPL | 视素材而定 | 可用，但必须逐条看协议 |
| itch.io | 综合 | 逐作者、逐包 | 视包而定 | 可用，CC0 包优先 |
| CraftPix | 2D 素材 | 自有协议（免费+付费） | 是，无需署名 | **可用**，禁转售、禁 AI 训练 |
| Lospec | 调色板 | 多为 CC0 | 是 | **推荐**，用于统一全项目色板 |
| game-icons.net | 图标 | **CC BY 3.0**（部分 CC0） | 是，**需署名** | 可用，UI/技能图标 |
| LPC (Liberated Pixel Cup) | 像素素材 | CC BY-SA 3.0 / GPL 3.0 | 是，但**传染性** | 慎用，闭源项目注意 |
| Freesound | 音效 | CC0 / CC BY / CC BY-NC | **仅 CC0 与 CC BY** | **首选**，务必过滤掉 BY-NC |
| ZapSplat | 音效/音乐 | 自有标准许可 | 是 | 可用；免费账号**需署名** |
| Sonniss #GameAudioGDC | 音效 | 自有免版税许可 | 是，**无需署名** | **强烈推荐** |
| Mixkit | 音效 | Mixkit SFX Free License | 是，无需署名 | **推荐**，明确允许游戏 |
| Pixabay | 图/音/视频 | Pixabay Content License | 是 | 可用，注意禁止转售原样内容 |
| 爱给网 | 音效 | CC 协议库 + 付费版权库 | CC 库可商用 | 可用，注意区分免费/付费区 |
| BBC Sound Effects | 音效 | BBC 自有 | **否** | **不可用于商业项目** |
| 思源黑体/宋体 | 字体 | **SIL OFL 1.1** | 是 | **首选正文字体** |
| 阿里巴巴普惠体 | 字体 | 免费商用声明 | 是 | **推荐** |
| MiSans | 字体 | 免费商用声明 | 是 | **推荐**，可嵌入 |
| HarmonyOS Sans | 字体 | 华为自有许可 | 是 | 可用，注意非 OFL |
| OPPO Sans | 字体 | 免费商用声明 | 是 | 可用，禁改编 |
| 站酷字体（部分） | 字体 | 免费商用（部分为付费） | 部分是 | 需逐个确认 |
| 方舟像素字体 | 像素中文字体 | **SIL OFL 1.1** | 是 | **本项目像素中文首选** |
| 缝合像素字体 | 像素中文字体 | **SIL OFL 1.1** | 是 | **本项目像素中文首选** |
| Cubic 11 俐方體 | 像素中文字体 | OFL 文本，明示可商用 | 是 | 可用 |
| **Zpix 最像素** | 像素中文字体 | **商用 USD $1000** | **需付费** | **不要用**（见 2.3） |

---

## 2.1 像素风 2D 游戏素材

### Kenney（已直连核实）★ 首选

- 官网：https://kenney.nl/assets
- 授权说明页：https://kenney.nl/support
- **授权模式：CC0（公有领域奉献）**。原话：「all game assets on the asset pages are public domain licensed (CC0). You're free to use them, even in commercial projects.」
- **署名：不要求**（愿意署名可以写 "Kenney"，但不得使用其 logo）
- 相关包：Snake Desert 等沙漠题材在素材库中；桌面/网页版索引见上，itch 镜像 https://kenney-assets.itch.io/sketch-desert ，OGA 镜像 https://opengameart.org/content/sketch-desert
- **判断：本项目基底素材的首选**。授权最干净、无任何附加条件、体量大。

### OpenGameArt.org

- 主页：https://opengameart.org/
- 许可 FAQ：https://opengameart.org/content/faq
- **授权模式：逐素材标注**——CC0 / CC BY 3.0/4.0 / CC BY-SA / GPL 2.0/3.0，有的素材同时挂多个协议（可任选其一遵守）
- 仅看 CC0 素材的入口：https://opengameart.org/taxonomy/term/4
- 沙漠题材具体条目：
  - Free Desert Top-Down Tileset — https://opengameart.org/content/free-desert-top-down-tileset
  - 8x8 8-bit Styled Desert Tileset（作者自述 CC0/公有领域）— https://opengameart.org/content/8x8-8-bit-styled-desert-tileset
- **判断**：量大、题材契合，但**「站上有很多免费素材」不等于「这条素材可商用」**，必须点进每个素材条目看它挂的协议。CC BY-SA 有传染性，闭源项目要避开或改选 CC0 条目。

### itch.io

- 免费素材入口：https://itch.io/game-assets/free
- **授权模式：完全由作者自定**，同一站点上 CC0、CC BY、免费商用但禁转售、纯付费都有
- 具体可用包（已核验存在）：
  - **Ninja Adventure Asset Pack（CC0）** — https://pixel-boy.itch.io/ninja-adventure-asset-pack 。含 50+ 角色、30+ 怪物、tileset、UI、100+ 音效、37 首音乐、字体，全 CC0。**一包解决大量素材需求，强烈建议作为项目基底**
  - **Tiny Biomes: Desert 16x16（CC0）** — https://aldrin572.itch.io/tiny-biomes-desert 。作者明确写 "100% free (CC0)"
  - Free CC0 Top Down Tileset Template — https://rgsdev.itch.io/free-cc0-top-down-tileset-template-pixel-art
  - Tiny Swords (Pixel Frog) — https://pixelfrog-assets.itch.io/tiny-swords 。风格极佳，但**未能核实其授权文字**（itch 页面本机无法直连），**用前必须读包内 license 文件**
- **判断**：可选面最广，也最容易踩坑。**每个包内的 license 文件必读**，不要只看商品页描述。

### CraftPix（已直连核实）

- 免费区：https://craftpix.net/freebies/
- **授权说明页：https://craftpix.net/file-licenses/**
- **授权模式（免费素材条款 2. FREEBIE PRODUCTS）**：可用于**任意数量的个人与商业项目**；可修改并整合进游戏、网站、印刷品；**无需署名**（署名欢迎）
- **禁止**：转售或再分发源文件（PNG/JPG/EPS/AI 等）及轻微修改版；不得让终端用户能从你的应用里导出这些美术资源
- **2026 年注意**：许可新增第 3 节 **禁止将素材用于 AI 训练/微调**（「may not be used... for the purposes of training, fine-tuning, developing, testing, validating, or improving any artificial intelligence...」）
- **判断：可用**。条款清晰、无需署名，适合补齐 UI/HUD/图标类缺口。

### Lospec（调色板）

- 调色板库：https://lospec.com/palette-list
- 条款：https://lospec.com/terms-and-conditions
- **授权模式**：社区贡献，绝大多数调色板以 CC0 或同等宽松条件发布；**颜色数值本身不受版权保护**
- **判断：强烈推荐**用于统一全项目色板（尤其「火焰山红砂岩 + 沙黄 + 绿洲高饱和色带」这套主色，定死色板能避免多来源素材混用时色温不统一——这正是此前既定的采购策略要解决的问题）。

### game-icons.net

- 主页：https://game-icons.net/
- FAQ：https://game-icons.net/faq.html
- **授权模式：CC BY 3.0**（少数作者标注为 CC0/公有领域）
- **署名方式**（官方给的标准写法）：`Icons made by {author}. Available on https://game-icons.net`
- **判断**：4180+ 单色 SVG/PNG 图标，做技能、状态、UI 图标很合适。**必须署名**，请把署名写进游戏 credits 与 docs/asset-licenses.md。

### LPC（Liberated Pixel Cup）— 谨慎

- 项目主页：https://lpc.opengameart.org/
- FAQ：https://lpc.opengameart.org/content/faq
- **授权模式：CC BY-SA 3.0 与/或 GPL 3.0**
- **判断**：素材质量高，但 **CC BY-SA 具有传染性**（衍生作品需以相同协议发布），GPL 对闭源游戏同样麻烦。若本项目不打算开源，**应避开 LPC 素材**，改用 CC0 来源。

---

## 2.2 游戏音效与环境音

### Freesound（已直连核实）★ 首选

- 主页：https://freesound.org/
- **授权说明：https://freesound.org/help/faq/**
- **授权模式**：上传者三选一 —— **CC0**（可任意使用，含商用，甚至可转卖）/ **CC BY**（可商用，**须署名**）/ **CC BY-NC**（**禁止商用**）
- **本项目只能用 CC0 与 CC BY，必须排除 CC BY-NC**
- 只看 CC0：https://freesound.org/browse/tags/CC0/
- 站内许可解读（官方原话：「CC BYNC (non commercial): you cannot use these sounds for your project」）：https://freesound.org/forum/legal-help-and-attribution-questions/38715/
- **2026 年变化**：站方自 2026-07 起新增上传者的「生成式 AI 偏好」设置（在 CC 协议之上叠加偏好）。**对本项目（用音效，不训练模型）无影响**，但若未来做 AI 相关处理需重新评估。

### ZapSplat（已直连核实 license 页）

- 主页：https://www.zapsplat.com/
- **标准许可页：https://www.zapsplat.com/license-type/standard-license/**
- **署名说明：https://www.zapsplat.com/how-to-credit-us/**
- **授权模式**：Basic（免费）账号可商用，但**必须署名**；升级 Premium 后免除署名义务。许可为「全球、永久、非独占」
- **注意（已变动的地址）**：旧的许可入口 `https://www.zapsplat.com/license-type/` **现已 404**，新地址是上面的 `/license-type/standard-license/`。若你之前收藏过旧链接，需更新
- **判断：可用**，但免费账号要处理署名；本机抓取时 `zapsplat.com/faq/` 无法打开（连接失败），签约前请自行复核一次条款。

### Sonniss #GameAudioGDC ★ 强烈推荐

- 归档页：https://sonniss.com/gameaudiogdc/
- 2026 年包：https://gdc.sonniss.com/
- 许可页：https://sonniss.com/gdc-bundle-license/
- **授权模式**：免版税（royalty free）、**明确可商用**、**无需署名**、可用于无限数量项目
- 2026 包体量：7.47GB+、347+ 文件（历年包可累积，2024 包曾达 27.5GB+）
- **判断**：**性价比最高的音效来源**——体量巨大、无署名负担、明确商用。适合一次性建立环境音底库。

### Mixkit（已直连核实）

- 音效区：https://mixkit.co/free-sound-effects/
- **许可全文：https://mixkit.co/license/modal/sfxFree/**
- **授权模式**：Mixkit Sound Effects Free License —— **可商用、可非商用、免费、无需署名**；官方列举的允许场景**明确包含 Video games**；可下载、复制、修改、分发、公开表演
- **禁止**：将素材原样再分发（作为 stock、工具/模板、带源文件）；不得声称为自己所有或登记到权利管理平台
- **判断**：**推荐**。条款直白且点名了游戏场景。

### Pixabay

- 主页：https://pixabay.com/
- 许可摘要：https://pixabay.com/service/license-summary/
- 条款：https://pixabay.com/service/terms/
- **授权模式：Pixabay Content License**（免费商用、通常无需署名）。**重要**：只有 **2019-01-09 之前发布**的内容才是真正的 **CC0**；之后的内容适用 Pixabay 自有许可
- **禁止**：把内容原样作为独立商品转售/再分发；含可识别人物或商标的内容需另行取得授权
- **判断**：可用，但**不要把它当 CC0 用**。本机对该站抓取返回 403，条款以你打开时的页面为准。

### 爱给网（中文站）

- 音效区：https://www.aigei.com/sound
- 授权查询中心：https://www.aigei.com/license/center
- **授权模式：双轨** —— ①「CC 协议音效库」约 25.6 万首，标注**遵循 CC 许可协议，可免费商用**（页面另列 CC0/公共版权筛选）；②「版权音效」为**付费**（单首 4.99 元起，企业商用 199 元/首）
- **判断**：可用，中文检索方便。**必须分清免费 CC 区与付费区**，并按每首的具体 CC 类型决定是否署名。

### BBC Sound Effects —— 明确不可商用

- 许可页：https://sound-effects.bbcrewind.co.uk/licensing
- BBC 官方问答：https://www.bbc.co.uk/contact/questions/using-bbc-content/use-sound-effects
- **授权模式**：仅限**个人、教育、研究**用途；商业用途需另行取得授权
- **判断：本项目（参赛作品，且可能公开展示/商用）不可使用**，除非逐条购买授权。

---

## 2.3 可商用中文字体

### 通用正文字体（免费商用）

| 字体 | URL | 授权与要点 |
|---|---|---|
| 思源黑体 Source Han Sans | https://github.com/adobe-fonts/source-han-sans | **SIL OFL 1.1**。可自由使用、研究、修改、再分发（含商用）。OFL 限制：不得单独售卖字体文件本身 |
| 思源宋体 Source Han Serif | https://source.typekit.com/source-han-serif/cn/ | 同上，**SIL OFL 1.1** |
| Google 版 Noto Sans SC | https://fonts.google.com/noto/specimen/Noto+Sans+SC | 与思源同源，**OFL**，Web 端接入最方便 |
| 霞鹜文楷 LXGW WenKai | https://github.com/lxgw/LxgwWenKai | **SIL OFL 1.1**。作者提醒：淘宝/小红书上有商家倒卖，**不要购买**（违反 OFL 且钱不会到作者手里） |
| 得意黑 Smiley Sans | https://atelier-anchor.com/typefaces/smiley-sans | **SIL OFL 1.1**。窄斜体美术字，适合标题、招牌 |
| 未来荧黑 Glow Sans | https://github.com/welai/glow-sans | **SIL OFL 1.1**（代码 MIT）。基于思源黑体扩展，9 字重 + 宽度系列 |

### 厂商免费商用字体（自有声明，非 OFL）

| 字体 | URL | 授权与要点 |
|---|---|---|
| 阿里巴巴普惠体 | https://www.alibabafonts.com/ （下载站 https://fonts.alibabagroup.com/ ） | 官方声明免费商用。许可为**免费、不可转让、非独占**，可用于商业用途，须遵守其法律声明（不得篡改、不得违法使用等） |
| MiSans | https://hyperos.mi.com/font/zh/ （FAQ：https://hyperos.mi.com/font/zh/faq/ ，协议 PDF 在 font-download 下） | 官方 FAQ 原话：「MiSans Global 所有的字体都是**供全球免费商用**，您可以在任何平台、任何商业项目中使用所有字体」。**允许嵌入**，但需在软件中注明使用了 MiSans。不得单独更改字体外观后分发 |
| HarmonyOS Sans | https://developer.huawei.com/consumer/cn/design/resource-V1/ | 华为声明免费商用。**注意：不是 OFL，而是华为单方许可**，社区对其条款细节存在争议（参见 https://blog.xinshijiededa.men/font-license/hant/ ）。若项目需要「协议绝对清晰」，优先用思源系 |
| OPPO Sans 4.0 | https://www.coloros.com/article/A00000074/ | 官方：**免费授权全社会使用（含商用）**。限制：①不得改编或二次开发；②不得售卖字体；③不得提供其他下载渠道；④不得用于违法用途 |

### 站酷字体 —— 已变为「付费 + 免费」双轨，需逐个确认

- 字库主页：https://www.zcool.com.cn/special/zcoolfonts/
- **仍然明确免费商用**的经典款（资产页写明「免费授权全社会使用（包括商用）」）：
  - 站酷高端黑 — https://www.zcool.com.cn/assets/ZNTY0OA==
  - 站酷酷黑体 — https://www.zcool.com.cn/assets/ZNzg0MA==
- **已经变化的部分**：字库主页现在把「付费字体」放在默认列表，站酷型丽体、站酷妙典风云体、站酷锐锐体等一批字体显示为「**免费试用**」+「中小企业授权 / 大型企业授权」（授权购买跳转 hellorf）
- **判断**：站酷免费款仍可用，但 **网上「站酷字体全部免费商用」的说法已经过期**。用任意一款站酷字体前，务必打开它的资产页确认写的是哪种授权。

### 像素中文字体（本项目最需要的一类）★

| 字体 | URL | 授权与要点 |
|---|---|---|
| **方舟像素字体 Ark Pixel Font** | https://ark-pixel-font.takwolf.com/ | **SIL OFL 1.1**。开源的泛拉丁 + 泛中日韩像素字体，**10px / 12px**。本机已直连核实站点在线。**本项目像素中文首选** |
| **缝合像素字体 Fusion Pixel Font** | https://fusion-pixel-font.takwolf.com/ | **SIL OFL 1.1**（代码 MIT），**8px / 10px / 12px**。定位为方舟像素的过渡方案，由多个像素字体合并而成。本机已直连核实站点在线 |
| Cubic 11（俐方體 11 號） | https://github.com/ACh-K/Cubic-11 | 11×11 中文点阵字体（基于 M⁺ gothic 12r 衍生）。OFL 文本明确写「Unlimited permission is granted to use, copy, and distribute them, with or without modification, **either commercially or noncommercially**」。偏繁体字形，简体项目需评估 |

### ⚠️ 重要避坑：Zpix（最像素）已不是免费商用

- 仓库：https://github.com/SolidZORO/zpix-pixel-font
- 作者 README 的「License and Pricing」一节写明：**商用/商业产品（单产品）USD $1000**；多产品需联系作者
- 中文网络上大量「Zpix 免费商用」的文章（含字体聚合站）**已经过期或本身就是错的**
- 另有一条历史信息称其遵循 GPL V3 且「禁止一切商业贩售」，与现行 README 的付费条款不一致 —— **无论按哪种解读，都不能当作免费商用字体使用**
- **结论：本项目不要使用 Zpix。** 需要中文像素字体时，用 **方舟像素字体** 或 **缝合像素字体**（均为 SIL OFL 1.1，可商用）。

### 明确不可免费商用

方正、汉仪、字魂等商业字库（除其单独明确免费释放的个别字重外），默认均为付费授权，**不要使用**。

---

# 3. 结论与建议落地动作

## 3.1 美术（任务一）落地建议

1. **优先用 The Met Open Access（CC0）**取唐代织物/器物纹样——这是唯一「博物馆官网 + 明确可商用 + 无附加条件」的来源组合。
2. **形体参考用 Commons 分类页**：坎儿井→`Category:Turpan karez system`；交河/高昌→`Category:Jiaohe ruins` / `Category:Gaochang ruins`；晾房→`Category:Chunche`；毡房→`Category:Kazakh yurts`；乐器→`Category:Uyghur musical instruments`；地貌→`Category:Flaming Mountains` / `Category:Kumtag Desert (Turpan)`。
3. **每一张实际取用的参考图，都要点进文件页确认协议**（分类页不授权）。
4. **艾德莱斯绸的地域问题**：Commons/Openverse 上的可商用 ikat 织物多为乌兹别克/塔吉克产地。要么确认拍摄于和田/洛浦，要么用 AI 生成纹样并标注，**不要冒用地域**。
5. **手鼓（dap）没有专属 Commons 分类**，需要从 `Category:Frame drums` 人工筛选，或参考 Met 藏品 `Frame drum (Chinese Uighyur)`（CC0）。

## 3.2 素材（任务二）落地建议

1. **像素素材基底**：itch.io 的 **Ninja Adventure Asset Pack（CC0）** + **Kenney（CC0）** + OpenGameArt 的 **CC0 沙漠包**。三者协议都干净。这样比一张张搜散图更能保证光影与色温统一。
2. **色板**：用 **Lospec**（CC0）先定死主色板再动手画，避免多来源素材混用时色调打架。
3. **音效**：**Sonniss #GameAudioGDC**（免版税、免署名、体量大）建立底库 → 再用 **Freesound 的 CC0 标签**和 **Mixkit** 补特定音效。**绝对排除 CC BY-NC 与 BBC**。
4. **像素中文字体**：**方舟像素字体（OFL）** 或 **缝合像素字体（OFL）**。避开 Zpix。
5. **授权登记**：沿用既有要求——每引入一个素材，立刻在 `docs/asset-licenses.md` 记录**来源 URL、授权类型、证明材料、日期**，不要事后补记。参考图也应单独登记，并注明「仅参考，未使用原件」。

## 3.3 本报告未能完成的部分（需要人工补做）

1. **Commons 每个文件页的具体协议**未能打开确认（本机无法直连 Wikimedia）。以上所有 Commons 链接**只能确认页面在线**，不能确认具体协议文本。
2. **Met / UNESCO / Smithsonian / itch.io / Pixabay / Sonniss 的页面条款**未能直连读取（403 / 连接失败），仅通过实时搜索索引核验存在与要点。
3. **Tiny Swords (Pixel Frog) 的授权文字**未能核实，用前必须读包内 license。
4. **HarmonyOS Sans 的完整许可文本**未能取得（华为开发者页需登录/JS 渲染），存在社区争议，建议改用思源系字体以规避不确定性。
5. **`未找到明确授权来源`的类别**：
   - 维吾尔族**手鼓（dap）专属**的可授权图片集 —— 无专属 Commons 分类，Hartenberger 收藏站无授权说明。
   - **新疆产艾德莱斯绸**的可商用实拍图 —— Commons 上同类图多为乌兹别克/塔吉克产地，未能找到「确认拍摄于新疆 + 授权明确」的可商用样本。
   - **唐代西域铜器**的开放授权图片 —— Met/Commons 上唐代铜器样本远少于织物与陶瓷，未找到明确 CC0 的西域铜器专项来源。
