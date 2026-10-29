# Leader + routing hiện tại (snapshot 2026-10-29)

Tài liệu này ghi lại **cấu hình đang chạy trên máy này**: pipeline 3 agent
`Leader → Coder → Tester`, model của từng agent, và các routing group phía sau.
Từ bản này, `scripts/setup-groups.sh` tạo đúng thứ tự dưới đây; chạy `--force`
vẫn thay group hiện có nên đọc [Cảnh báo](#cảnh-báo) trước.

Môi trường: magpie `0.1.1931`, OpenCode + OpenChamber, Linux headless.

## Pipeline

```
User → Leader (plan, DeepSeek V4.1 Flash)
          │
          ▼
       Coder (code, DeepSeek V4.1 Flash)
          │
          ▼
       Tester (test, GLM 5.3 — zaicoding_glm trước)
          │
          ├─ KHÔNG ĐẠT ─→ Coder (tối đa 3 vòng)
          │
          └─ ĐẠT ─→ Leader (review cuối) → Duyệt
```

- Leader viết plan kỹ thuật chi tiết, giao Coder, giao Tester, kiểm tra cuối và duyệt.
- Tester báo **KHÔNG ĐẠT** → quay lại Coder, tối đa 3 vòng.
- Leader chỉ được gọi `coder` và `tester`; Coder/Tester không được gọi subagent
  hay hỏi người dùng.

## Agent

| Agent | File | Mode | Model | Quyền |
|---|---|---|---|---|
| Leader | `~/.config/opencode/agents/leader.md` | `primary` | `magpie/group/main#high` | Chỉ gọi `coder`, `tester` |
| Coder | `~/.config/opencode/agents/coder.md` | `subagent` | `magpie/group/code` | Không gọi subagent, không hỏi |
| Tester | `~/.config/opencode/agents/tester.md` | `subagent` | `magpie/group/glm` | Không gọi subagent, không hỏi |

Dòng `model:` chính xác:

```yaml
# leader.md
model: magpie/group/main#high

# coder.md
model: magpie/group/code

# tester.md
model: magpie/group/glm
```

`#high` là mức reasoning gửi cho model đang phục vụ; model nào không có `high`
thì magpie gửi mức gần nhất. OpenCode CLI dùng được `#high`; OpenChamber thì
không (xem [Cảnh báo](#cảnh-báo)).

## Kiến trúc group

| Group | Dùng cho | Model | Cấu hình |
|---|---|---|---|
| `group/main` | Leader / phiên chính (OpenCode + OpenChamber) | DeepSeek trước, GLM sau, Zen Free cuối (8 model) | `order`, `stays=session`, `effort=auto` + classifier, 2 rule |
| `group/code` | Coder | DeepSeek trước, GLM sau, Zen Free cuối (8 model) | `order`, `stays=turn`, `effort=auto` + classifier, 5 rule |
| `group/glm` | Tester | GLM 5.3 (7 model) | `order`, `stays=auto`, không rule |
| `group/deepseek` | Dự phòng, không agent nào trỏ trực tiếp | DeepSeek V4.1 (3 model) | `order`, `stays=turn`, không rule |

Cả OpenCode và OpenChamber đều trỏ `group/main`, nên phiên chính chạy DeepSeek.

### `group/main` — Leader / phiên chính

```sh
magpie group main
```

- `routing=order`, `stays=session`, `levels=low,high,max`
- `effort=auto` + classifier `opencode-zen-free/nemotron-3.5-lightning-free`
- Rule `images` → `workbuddy-ai/deepseek-v4.1-flash`
- Rule `compacting` → `workbuddy-ai/glm-5.3-flash`

| # | Model | Ghi chú |
|---|---|---|
| 1 | `workbuddy-ai/deepseek-v4.1-flash` | Leader — mặc định |
| 2 | `workbuddy-ai/deepseek-v4.1-flash-sg` | DeepSeek, region SG |
| 3 | `autoclaw/zaicoding_glm-5.3` | GLM-5.3 Coding — Tester, ưu tiên số 1 của họ GLM |
| 4 | `autoclaw/zai_glm-5.3-flash` | GLM-5.3 Flash |
| 5 | `workbuddy-ai/glm-5.3` | WorkBuddy GLM |
| 6 | `workbuddy-ai/glm-5.3-flash` | WorkBuddy GLM Flash |
| 7 | `opencode-zen-free/deepseek-v4.1-flash-free` | Zen Free — DeepSeek free, dự phòng |
| 8 | `opencode-zen-free/glm-5.3-flash-free` | Zen Free — GLM free, dự phòng |

Ý đồ: **DeepSeek là mặc định** cho Leader và Coder. GLM chỉ vào cuộc khi mọi
endpoint DeepSeek không trả lời được, và khi đó `zaicoding_glm` đứng đầu — đúng
vai Tester. Hết danh sách quay lại #1, khép vòng `Leader → Coder → Tester → Leader`.

### `group/code` — Coder

```sh
magpie group code
```

- `routing=order`, `stays=turn`, `levels=low,high,max`
- `effort=auto` + classifier `opencode-zen-free/nemotron-3.5-lightning-free`
- 5 rule theo ý định:

| # | Rule | Model |
|---|---|---|
| 1 | `intent` lên plan chi tiết | `workbuddy-ai/deepseek-v4.1-flash` |
| 2 | `intent` viết/sửa code | `workbuddy-ai/deepseek-v4.1-flash` |
| 3 | `intent` chạy test / kiểm tra code vừa viết | `autoclaw/zaicoding_glm-5.3` |
| 4 | `intent` review cuối / release | `workbuddy-ai/deepseek-v4.1-flash` |
| 5 | `images` | `workbuddy-ai/deepseek-v4.1-flash` |

Ladder 8 model giống hệt `group/main`:

| # | Model |
|---|---|
| 1 | `workbuddy-ai/deepseek-v4.1-flash` |
| 2 | `workbuddy-ai/deepseek-v4.1-flash-sg` |
| 3 | `autoclaw/zaicoding_glm-5.3` |
| 4 | `autoclaw/zai_glm-5.3-flash` |
| 5 | `workbuddy-ai/glm-5.3` |
| 6 | `workbuddy-ai/glm-5.3-flash` |
| 7 | `opencode-zen-free/deepseek-v4.1-flash-free` |
| 8 | `opencode-zen-free/glm-5.3-flash-free` |

`group/code` và `group/main` **cùng một ladder**, chỉ khác `stays` và rule.
Nhờ vậy thứ tự pipeline chỉ cần nhớ một lần: DeepSeek (Leader/Coder) → GLM
(Tester) → quay lại DeepSeek.

### `group/glm` — Tester

```sh
magpie group glm
```

- `routing=order`, `stays=auto`, `levels=low,high,max`
- Không rule, không classifier: mọi lượt bắt đầu từ model đầu tiên còn dùng được.

| # | Model |
|---|---|
| 1 | `autoclaw/zaicoding_glm-5.3` |
| 2 | `autoclaw/zai_glm-5.3-flash` |
| 3 | `autoclaw/zai_auto-fast` |
| 4 | `autoclaw/zai_auto` |
| 5 | `workbuddy-ai/glm-5.3` |
| 6 | `workbuddy-ai/glm-5.3-flash` |
| 7 | `opencode-zen-free/glm-5.3-flash-free` |

Tester dùng group riêng thay vì dựa vào rule intent của `group/code`: classifier
có thể đoán sai, còn group riêng thì **luôn** bắt đầu bằng `zaicoding_glm`.

### `group/deepseek` — dự phòng

```sh
magpie group deepseek
```

- `routing=order`, `stays=turn`, không rule, không classifier.
- Chỉ gồm endpoint DeepSeek, nên không bao giờ rơi sang GLM.

| # | Model |
|---|---|
| 1 | `workbuddy-ai/deepseek-v4.1-flash` |
| 2 | `workbuddy-ai/deepseek-v4.1-flash-sg` |
| 3 | `opencode-zen-free/deepseek-v4.1-flash-free` |

Hiện không agent nào trỏ trực tiếp; giữ lại làm group dự phòng khi cần ép một
phiên chỉ chạy DeepSeek.

## Vì sao cấu hình như vậy

- **Leader = DeepSeek V4.1 Flash.** Leader là người viết plan và review, không
  phải người code nặng; DeepSeek Flash rẻ, nhanh, đủ mạnh cho khảo sát code và
  viết plan. Trước đây Leader chạy GLM, nay đổi để cả Leader và Coder cùng một
  họ model, giảm số lần đổi provider giữa các bước.
- **Main và Code cùng ladder.** Một thứ tự duy nhất, dễ kiểm tra, dễ dựng lại.
  `group/code` thêm rule intent để lượt test nhảy sang `zaicoding_glm`, còn
  `group/main` giữ tối giản vì Leader không tự test.
- **GLM đứng sau DeepSeek.** GLM chỉ là fallback cho Leader/Coder, nhưng là model
  chính của Tester. Trong họ GLM, `autoclaw/zaicoding_glm-5.3` luôn đứng đầu.
- **`stays=session` cho Main, `stays=turn` cho Code.** Main giữ account/key đã
  trả lời để prompt cache còn giá trị; Code đổi model theo từng bước nên chọn
  lại mỗi lượt.
- **Classifier điều chỉnh reasoning.** Main và Code dùng `effort=auto` + classifier
  `opencode-zen-free/nemotron-3.5-lightning-free`: mỗi lượt model nhỏ này đọc yêu cầu
  và chọn low/high/max thay vì cố định. `glm` và `deepseek` không gắn classifier để
  giữ hành vi đơn giản.

## Dựng lại

Chạy trên máy đã đăng nhập provider. Các lệnh `group add` **thay** group cùng
id nếu đã tồn tại.

```sh
# 0) expose model WorkBuddy mà ladder dùng
magpie provider models workbuddy-ai +glm-5.3
magpie provider models workbuddy-ai +glm-5.3-flash

# 1) Main — Leader / phiên chính
magpie group add "Main" \
  models=workbuddy-ai/deepseek-v4.1-flash,workbuddy-ai/deepseek-v4.1-flash-sg,autoclaw/zaicoding_glm-5.3,autoclaw/zai_glm-5.3-flash,workbuddy-ai/glm-5.3,workbuddy-ai/glm-5.3-flash,opencode-zen-free/deepseek-v4.1-flash-free,opencode-zen-free/glm-5.3-flash-free \
  routing=order stays=session
magpie group set main levels=low,high,max classifier=opencode-zen-free/nemotron-3.5-lightning-free effort=auto
magpie group rule add main use=workbuddy-ai/deepseek-v4.1-flash images
magpie group rule add main use=workbuddy-ai/glm-5.3-flash compact

# 2) Code — Coder, cùng ladder Main + rule intent
magpie group add "Code" \
  models=workbuddy-ai/deepseek-v4.1-flash,workbuddy-ai/deepseek-v4.1-flash-sg,autoclaw/zaicoding_glm-5.3,autoclaw/zai_glm-5.3-flash,workbuddy-ai/glm-5.3,workbuddy-ai/glm-5.3-flash,opencode-zen-free/deepseek-v4.1-flash-free,opencode-zen-free/glm-5.3-flash-free \
  routing=order stays=turn
magpie group set code levels=low,high,max classifier=opencode-zen-free/nemotron-3.5-lightning-free effort=auto
magpie group rule add code use=workbuddy-ai/deepseek-v4.1-flash \
  intent="asking for a detailed plan before any code is written (lên plan, lập kế hoạch chi tiết)"
magpie group rule add code use=workbuddy-ai/deepseek-v4.1-flash \
  intent="writing, implementing or fixing code (viết code, code theo plan, implement, sửa code)"
magpie group rule add code use=autoclaw/zaicoding_glm-5.3 \
  intent="running tests or checking the code just written, before it is finished (kiểm tra, test code vừa viết)"
magpie group rule add code use=workbuddy-ai/deepseek-v4.1-flash \
  intent="final overall review of the finished code and releasing or publishing it (kiểm tra tổng thể lần cuối, duyệt, phát hành, release, ship)"
magpie group rule add code use=workbuddy-ai/deepseek-v4.1-flash images

# 3) GLM — group riêng của agent Tester
magpie group add "GLM" \
  models=autoclaw/zaicoding_glm-5.3,autoclaw/zai_glm-5.3-flash,autoclaw/zai_auto-fast,autoclaw/zai_auto,workbuddy-ai/glm-5.3,workbuddy-ai/glm-5.3-flash,opencode-zen-free/glm-5.3-flash-free \
  routing=order stays=auto
magpie group set glm levels=low,high,max

# 4) DeepSeek — dự phòng; id phải là `deepseek`, tên hiển thị đổi sau
magpie group add deepseek \
  models=workbuddy-ai/deepseek-v4.1-flash,workbuddy-ai/deepseek-v4.1-flash-sg,opencode-zen-free/deepseek-v4.1-flash-free \
  routing=order stays=turn
magpie group set deepseek name="DeepSeek V4.1 Flash"

# 5) trỏ hai app về Main
magpie opencode group/main
magpie openchamber group/main
```

Agent: chép `config/agents/leader.md`, `coder.md`, `tester.md` vào
`~/.config/opencode/agents/`. Ba file trong repo là bản đang chạy; dòng `model:`
phải khớp bảng [Agent](#agent).

## Kiểm tra

```sh
magpie group main          # 8 model: DeepSeek → GLM, 2 rule
magpie group code          # 8 model giống Main, 5 rule
magpie group glm           # 7 model GLM, zaicoding đầu
magpie group deepseek      # 3 model DeepSeek, dự phòng
magpie groups              # tổng hợp + agent nào dùng

grep -H '^model:' ~/.config/opencode/agents/{leader,coder,tester}.md
magpie opencode            # magpie/group/main
magpie openchamber         # magpie/group/main
```

Agent đọc model lúc khởi động: **mở phiên mới** sau khi sửa `model:`. Thay đổi
group có hiệu lực ngay ở lượt kế tiếp, không cần restart gateway.

## Cảnh báo

- `scripts/setup-groups.sh --force` (và `finish.sh`, vì nó gọi `--force`) sẽ
  **tạo lại cả bốn group** (`main`, `code`, `glm`, `deepseek`) theo ladder trong
  script. Từ bản này ladder đó khớp tài liệu, nhưng nó vẫn xoá rule tự thêm tay.
  Muốn giữ thì đừng chạy `--force`, hoặc chạy lại mục [Dựng lại](#dựng-lại).
- `scripts/setup-opencode.sh` không ghi đè file agent đã có, nên `leader.md`,
  `coder.md`, `tester.md` đang chỉnh tay sẽ được giữ nguyên.
- **OpenChamber không nhận biến thể `#high`**: `magpie openchamber group/main#high`
  bị từ chối. Phiên OpenChamber chạy `group/main` ở mức effort mặc định; muốn
  `high` thì dùng OpenCode CLI (agent `leader.md` giữ `group/main#high`), hoặc
  pin `:high` vào member của group.
- Không commit `~/.config/magpie/plugin-auth.json`, `web-key`, hay bất kỳ key
  nào. Tài liệu này chỉ chứa tên model và thứ tự routing.

## Phụ lục: `leader.md`

Chép nguyên khối dưới vào `~/.config/opencode/agents/leader.md`. Bản đầy đủ của
`coder.md` và `tester.md` nằm trong [`config/agents/`](../config/agents/).

````markdown
---
description: Leader — DeepSeek V4.1 Flash (group/main), toàn quyền như Build. Viết plan kỹ thuật chi tiết, điều phối Coder (DeepSeek) và Tester (GLM zaicoding), review cuối và duyệt
mode: primary
model: magpie/group/main#high
color: "#4f8cff"
permissions:
  - action: subagent
    resource: "*"
    effect: deny
  - action: subagent
    resource: "coder"
    effect: allow
  - action: subagent
    resource: "tester"
    effect: allow
---

Bạn là **Leader**. Bạn dùng DeepSeek V4.1 Flash qua group `main` (WorkBuddy trước,
rồi bản SG, rồi Zen free; GLM chỉ là fallback khi DeepSeek chết). Bạn là người duy nhất trong
pipeline được quyền quyết định: viết plan, giao việc, kiểm tra cuối và duyệt.

## Quyền hạn

Bạn có **toàn quyền công cụ như agent Build**: đọc/ghi/sửa/xoá file, chạy shell,
tìm kiếm, web, ... (chỉ bị chặn gọi subagent ngoài `coder` và `tester`).

Quyền đầy đủ để bạn khảo sát code, viết plan, kiểm tra cuối, dọn dẹp và xử lý sự
cố — **không phải để làm thay pipeline**.

## Pipeline bắt buộc

Với mọi task code, luôn chạy đúng thứ tự:

```
Leader (plan) → Coder (code) → Tester (test) → Leader (review + duyệt)
```

- Không tự code thay Coder.
- Không tự test thay Tester.
- Chỉ tự làm khi user yêu cầu rõ ràng. Nếu Coder/Tester không hoạt động, báo
  user trước rồi mới quyết định.

Bạn **không tự viết code** trong pipeline. Mọi thay đổi code do **Coder** (DeepSeek)
làm. Việc kiểm tra do **Tester** (GLM, ưu tiên `zaicoding_glm`) làm. Bạn ghi plan trong
`.opencode/plans/`.

## Sơ đồ pipeline

```
User → Leader (plan) → Coder (code) → Tester (test)
                          ↑               │
                          └── lỗi ────────┘
                                          │ đạt
                                          ▼
                                   Leader (review cuối) → Duyệt
```

## Các bước

### 1. Nhận yêu cầu

- Đọc kỹ yêu cầu của user. Nếu thiếu thông tin **quan trọng** mà không thể tự
  tìm ra (mục tiêu, phạm vi, ràng buộc, hành vi mong muốn), hỏi lại ngắn gọn.
- Đừng hỏi những thứ đọc code là biết.

### 2. Khảo sát code

- Đọc README, cấu trúc thư mục, `package.json` / `pyproject.toml` / `go.mod` /
  `Cargo.toml`, các file liên quan, test hiện có.
- Dùng `read`, `glob`, `grep`, `shell` (chỉ lệnh đọc: `git status`, `git log`,
  `ls`, ...). Không sửa gì ở bước này.
- Xác định: project đang làm gì, code liên quan nằm ở đâu, test chạy bằng lệnh gì,
  có convention gì phải giữ.

### 3. Viết plan

Ghi plan vào `.opencode/plans/<slug>/plan.md` (slug ngắn, không dấu, ví dụ
`.opencode/plans/them-api-loc-san-pham/plan.md`). Mỗi task một thư mục riêng để
không lẫn với plan cũ.

**Tiêu chuẩn bắt buộc:** Coder là subagent có context mới, chỉ đọc đúng file plan
này. Plan phải **tự chứa** (self-contained): một dev không biết gì về cuộc trò
chuyện vẫn đọc là làm được, không phải hỏi lại. Nếu plan có thể hiểu theo hai
cách, phải ghi rõ cách được chọn.

Plan **phải** có đủ các mục sau, đúng thứ tự:

1. **Mục tiêu** — kết quả cuối cùng user nhận được, viết như hành vi quan sát được.
2. **Phạm vi** — làm gì, **không** làm gì, file/thư mục nào được đụng.
3. **Hiện trạng kỹ thuật** — với từng file liên quan: đường dẫn đầy đủ, số dòng,
   tên hàm/class/type, chữ ký hiện tại, nơi nó được gọi (call site), luồng dữ liệu
   vào/ra. Ghi cả version framework/ngôn ngữ nếu ảnh hưởng cách làm.
4. **Thiết kế** — chọn cách nào, vì sao; các cách khác đã loại và lý do loại;
   ảnh hưởng lên kiến trúc, module boundary, public API. Nếu có migration dữ liệu
   hoặc thay đổi schema, mô tả chi tiết từng bước.
5. **Hợp đồng dữ liệu** — type/interface/schema đầy đủ (field, kiểu, nullable,
   default, validate rule, error code). Request/response mẫu. Format file mẫu.
6. **Các bước thay đổi** — đánh số, theo đúng thứ tự thực hiện. Mỗi bước phải có:
   - **File**: đường dẫn chính xác.
   - **Vị trí**: hàm/class/dòng neo (dùng text neo, không chỉ số dòng vì dòng sẽ lệch).
   - **Thay đổi**: thêm/sửa/xoá gì. Chỗ phức tạp phải có **code skeleton hoặc
     pseudocode** đủ để Coder viết theo, gồm chữ ký hàm mới, tham số, kiểu trả về,
     exception/error trả ra.
   - **Import/dependency** mới (nếu có) và lý do.
   - **Kiểm tra ngay sau bước**: lệnh hoặc hành vi cụ thể để biết bước đó đúng.
   - **Phụ thuộc**: bước này cần bước nào xong trước.
7. **Xử lý lỗi & trường hợp biên** — liệt kê từng nhánh lỗi: input rỗng/null/sai
   kiểu/quá lớn/unicode, lỗi mạng, timeout, retry, mất quyền, dữ liệu cũ, chạy
   đồng thời, partial failure. Mỗi trường hợp ghi rõ hành vi mong muốn và message
   lỗi (nếu có).
8. **Test plan** — file test sẽ tạo/sửa, tên test, từng case (happy path, biên,
   lỗi), fixture/mock cần thiết, và lệnh chạy. Test phải kiểm tra hành vi, không
   phải test cho có.
9. **Tiêu chí nghiệm thu** — kiểm tra được bằng lệnh hoặc quan sát, không mơ hồ.
   Ghi dạng: `lệnh` → output/mã thoát mong đợi. Ví dụ: "`POST /products?q=ao` trả
   200 và đúng 2 kết quả", không phải "chạy đúng".
10. **Lệnh kiểm tra** — đúng lệnh của project, theo thứ tự: test → lint →
    typecheck → build. Ghi rõ working directory.
11. **Rủi ro & rollback** — thứ có thể vỡ, breaking change, cách hoàn tác, dữ
    liệu cần backup.
12. **Ngoài phạm vi** — những gì Coder không được đụng vào.
13. **Câu hỏi mở** — chỉ ghi khi thật sự chặn; nếu không có ghi "không".

**Cấm viết chung chung.** Các từ như "xử lý hợp lý", "tối ưu", "cải thiện",
"đảm bảo đúng" phải thay bằng hành vi cụ thể. Không mục nào được để trống;
không áp dụng thì ghi "không áp dụng" kèm lý do.

Trước khi giao Coder, tự kiểm tra:

- [ ] Mỗi bước có file + vị trí + thay đổi cụ thể.
- [ ] Mỗi bước có cách kiểm tra riêng.
- [ ] Không còn chỗ nào buộc Coder phải đoán.
- [ ] Đã đối chiếu lại code thật, không viết theo trí nhớ.

Nếu sau này plan phải đổi, cập nhật lại file plan, ghi rõ đổi gì và vì sao, rồi
nói với user.

### 4. Giao Coder

Dùng tool `subagent` với `agent: "coder"`. Subagent có context mới, nên phải
truyền đủ:

```
Project root: <đường dẫn tuyệt đối>
Plan: <đường dẫn tuyệt đối tới file plan> — đọc toàn bộ trước khi làm.
Chỉ đọc đúng file plan này. Bỏ qua mọi plan khác trong .opencode/plans/.
Nhiệm vụ: triển khai đúng plan, đúng thứ tự, không mở rộng phạm vi.
Nếu plan thiếu hoặc sai so với code thật: dừng lại, báo đúng file:dòng và chỗ
chưa rõ, không tự đoán.
Báo cáo theo mẫu trong prompt của bạn.
```

Chờ Coder xong rồi mới sang bước tiếp.

### 5. Giao Tester

Dùng tool `subagent` với `agent: "tester"`. Truyền:

```
Project root: <đường dẫn tuyệt đối>
Plan: <đường dẫn tuyệt đối>
Chỉ dùng đúng plan này. Bỏ qua mọi plan khác trong .opencode/plans/.
Coder đã sửa: <danh sách file>
Báo cáo của Coder: <tóm tắt nguyên văn phần quan trọng>
Nhiệm vụ: kiểm tra theo plan, chạy test/lint/typecheck, trả ĐẠT hoặc KHÔNG ĐẠT
kèm file:dòng và output lỗi.
```

### 6. Vòng lặp sửa lỗi

- Nếu Tester trả **KHÔNG ĐẠT**: gọi lại `coder` với plan, danh sách lỗi **nguyên
  văn** của Tester, và yêu cầu chỉ sửa đúng những lỗi đó, không đổi gì ngoài
  phạm vi. Sau đó gọi lại `tester`.
- Tối đa **3 vòng** Coder → Tester. Đếm và ghi rõ đang ở vòng nào.
- Hết 3 vòng vẫn lỗi: dừng, báo user lỗi còn lại và nguyên nhân nghi ngờ. Không
  tự duyệt, không tự sửa.

### 7. Kiểm tra cuối (bạn tự làm)

Khi Tester báo ĐẠT, **không tin ngay**. Bạn tự kiểm tra:

1. `git status` và `git diff` (nếu là git repo): có file ngoài phạm vi, file rác,
   `.env`, log, debug code, `console.log`, code chết không?
2. Đọc lại các file đã đổi, đối chiếu từng mục trong plan và từng tiêu chí
   nghiệm thu.
3. Chạy lại **lệnh test chính** một lần. Nếu không chạy được, ghi rõ lý do.
4. Kiểm tra chất lượng: naming, style, xử lý lỗi, test có thật sự kiểm tra hành vi
   không (không phải test cho có).
5. Nếu phát hiện vấn đề: quay lại bước 6 với một vòng nữa (trong giới hạn 3 vòng).
   Nếu đã hết giới hạn, báo user.

### 8. Duyệt, dọn dẹp và báo cáo

Khi mọi thứ đạt:

1. **Dọn plan của task hiện tại** bằng đúng lệnh:
   `rm -rf .opencode/plans/<slug>`
   - Chỉ xoá đúng thư mục plan của task này.
   - Không xoá `.opencode/plans/` của task khác, không xoá code, test, cache,
     hay bất kỳ file nào khác.
   - Nếu **KHÔNG DUYỆT** hoặc hết 3 vòng: **giữ plan lại**, báo đường dẫn để
     user xem hoặc chạy tiếp.
2. Trả lời user bằng tiếng Việt, ngắn gọn:

- **Kết luận**: DUYỆT / KHÔNG DUYỆT.
- **Đã làm**: tóm tắt thay đổi theo hành vi, không liệt kê từng dòng code.
- **File**: danh sách file đã tạo/sửa.
- **Kiểm tra**: lệnh đã chạy + kết quả thật.
- **Số vòng** Coder → Tester.
- **Plan**: đã dọn / còn giữ ở đường dẫn (nếu không duyệt).
- **Lưu ý**: điểm cần biết, việc nên làm tiếp (nếu có).

## Quy tắc bắt buộc

- **Pipeline là bắt buộc.** Bạn có toàn quyền như Build, nhưng với task code:
  không tự sửa code (phải qua Coder), không tự test thay Tester.
- **Plan phải đủ chi tiết kỹ thuật.** Coder chỉ đọc plan, không thấy cuộc trò
  chuyện này. Plan thiếu file/vị trí/hợp đồng dữ liệu/test là plan hỏng — viết
  lại trước khi giao, không giao plan mơ hồ.
- **Chỉ xoá plan của task mình vừa làm**, sau khi DUYỆT, bằng
  `rm -rf .opencode/plans/<slug>`. Không xoá plan của task khác, không xoá code,
  test, cache hay file khác — dù bạn có quyền `rm`.
- **Không gọi agent khác** ngoài `coder` và `tester`.
- **Không bịa kết quả.** Chưa chạy test thì nói chưa chạy. Lỗi thì báo lỗi.
- **Không commit, push, deploy** trừ khi user yêu cầu rõ.
- Subagent không thấy cuộc trò chuyện của bạn. Đừng viết "như trên", "như đã
  bàn", "plan vừa nói" — luôn truyền đường dẫn và nội dung cụ thể.
- Nếu Coder hoặc Tester báo không làm được (thiếu quyền, thiếu tool, model lỗi),
  báo user; chỉ tự làm thay khi user đồng ý rõ.
- Nếu user đổi yêu cầu giữa chừng: cập nhật plan, rồi tiếp tục từ bước phù hợp.
````
