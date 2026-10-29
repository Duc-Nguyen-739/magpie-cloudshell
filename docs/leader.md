# Leader + routing hiện tại (snapshot 2026-10-29)

Tài liệu này ghi lại **cấu hình đang chạy trên máy này**: pipeline 3 agent
`Leader → Coder → Tester`, model của từng agent, và các routing group phía sau.
Đây không phải ladder mặc định của `scripts/setup-groups.sh` — xem
[Cảnh báo](#cảnh-báo) trước khi chạy `--force`.

Môi trường: magpie `0.1.1931`, OpenCode + OpenChamber, Linux headless.

## Pipeline

```
User → Leader (GLM 5.3) → Coder (DeepSeek V4.1) → Tester (DeepSeek V4.1)
                          ↑                            │
                          └──────── lỗi ───────────────┘
                                                       │ đạt
                                                       ▼
                                            Leader review → Duyệt
```

- Leader viết plan, giao Coder, giao Tester, kiểm tra cuối và duyệt.
- Tester báo **KHÔNG ĐẠT** → quay lại Coder, tối đa 3 vòng.
- Leader chỉ được gọi `coder` và `tester`; Coder/Tester không được gọi subagent
  hay hỏi người dùng.

## Agent

| Agent | File | Mode | Model | Quyền |
|---|---|---|---|---|
| Leader | `~/.config/opencode/agents/leader.md` | `primary` | `magpie/group/glm#high` | Chỉ gọi `coder`, `tester` |
| Coder | `~/.config/opencode/agents/coder.md` | `subagent` | `magpie/group/code` | Không gọi subagent, không hỏi |
| Tester | `~/.config/opencode/agents/tester.md` | `subagent` | `magpie/group/deepseek` | Không gọi subagent, không hỏi |

Dòng `model:` chính xác:

```yaml
# leader.md
model: magpie/group/glm#high

# coder.md
model: magpie/group/code

# tester.md
model: magpie/group/deepseek
```

`#high` là mức reasoning gửi cho model đang phục vụ; model nào không có `high`
thì magpie gửi mức gần nhất. OpenCode CLI dùng được `#high`; OpenChamber thì
không (xem [Cảnh báo](#cảnh-báo)).

## Kiến trúc group

| Group | Dùng cho | Model | Cấu hình |
|---|---|---|---|
| `group/main` | Leader / phiên chính (OpenCode + OpenChamber) | GLM 5.3 (7 model) | `order`, `stays=auto`, 1 rule `compact` |
| `group/code` | Coder | DeepSeek V4.1 (3 model) | `order`, `stays=auto`, 1 rule `compact` |
| `group/glm` | Leader agent | GLM 5.3 (7 model) | `order`, `stays=auto`, không rule |
| `group/deepseek` | Tester | DeepSeek V4.1 (3 model) | `order`, `stays=turn`, không rule |

Cả OpenCode và OpenChamber đều trỏ `group/main`, nên phiên chính chạy GLM.

### `group/main` — Leader / phiên chính

```sh
magpie group main
```

- `routing=order`, `stays=auto`, `levels=low,high,max`
- Rule `compact` → `autoclaw/zai_glm-5.3-flash`

| # | Model | Ghi chú |
|---|---|---|
| 1 | `autoclaw/zaicoding_glm-5.3` | GLM-5.3 Coding — mặc định |
| 2 | `autoclaw/zai_glm-5.3-flash` | GLM-5.3 Flash |
| 3 | `autoclaw/zai_auto-fast` | GLM Auto Fast |
| 4 | `autoclaw/zai_auto` | GLM Auto (路由) |
| 5 | `opencode-zen/glm-5.3-flash-free` | Zen free |
| 6 | `workbuddy-ai/glm-5.3` | WorkBuddy — dự phòng cuối |
| 7 | `workbuddy-ai/glm-5.3-flash` | WorkBuddy — dự phòng cuối |

Ý đồ: **AutoClaw là mặc định**. Hết quota/lỗi mới tụt dần; WorkBuddy nằm cuối
để không tiêu credit WorkBuddy khi AutoClaw còn dùng được. Khi quota hồi, lượt
sau lại thử từ #1.

### `group/code` — Coder

```sh
magpie group code
```

- `routing=order`, `stays=auto`, `levels=low,high,max`
- Rule `compact` → `opencode-zen/deepseek-v4.1-flash-free`
- Không rule intent, không classifier: mọi lượt đều DeepSeek.

| # | Model |
|---|---|
| 1 | `workbuddy-ai/deepseek-v4.1-flash` |
| 2 | `opencode-zen/deepseek-v4.1-flash-free` |
| 3 | `workbuddy-ai/deepseek-v4.1-flash-sg` |

`group/code` có **cùng cấu trúc với `group/main`** (order, stays auto, một rule
compact), chỉ đổi họ model sang DeepSeek.

### `group/glm` — Leader agent

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
| 5 | `opencode-zen/glm-5.3-flash-free` |
| 6 | `workbuddy-ai/glm-5.3` |
| 7 | `workbuddy-ai/glm-5.3-flash` |

### `group/deepseek` — Tester

```sh
magpie group deepseek
```

- `routing=order`, `stays=turn`, không rule, không classifier.
- Chỉ gồm endpoint DeepSeek, nên không bao giờ rơi sang GLM.

| # | Model |
|---|---|
| 1 | `workbuddy-ai/deepseek-v4.1-flash` |
| 2 | `opencode-zen/deepseek-v4.1-flash-free` |
| 3 | `workbuddy-ai/deepseek-v4.1-flash-sg` |

## Vì sao cấu hình như vậy

- **Main = Leader (GLM).** OpenCode và OpenChamber đều trỏ `group/main`; trước
  đây OpenChamber trỏ `group/code` nên Leader thực tế chạy DeepSeek. Đổi Main
  sang ladder GLM và trỏ OpenChamber về Main thì phiên chính mới đúng là GLM.
- **Code = bản DeepSeek của Main.** Coder chỉ cần DeepSeek; giữ cùng cấu trúc
  order + stays auto + compact rule để dễ đọc, nhưng bỏ hết rule intent vì
  Tester đã có group riêng. Coder và Tester **không còn fallback GLM**.
- **WorkBuddy cuối ladder GLM.** AutoClaw là nguồn chính; WorkBuddy chỉ dùng khi
  AutoClaw hết. Hai model WorkBuddy phải được expose thủ công, nếu không magpie
  coi là "not exposed" và bỏ qua:

  ```sh
  magpie provider models workbuddy-ai +glm-5.3
  magpie provider models workbuddy-ai +glm-5.3-flash
  ```

- **`stays=auto` cho Main/Code/glm.** Giữ account/key đã trả lời trong lúc cache
  còn đáng giữ, nhưng không khóa model.
- **`stays=turn` cho Tester.** Mỗi lượt chọn lại endpoint; vì group chỉ có
  DeepSeek nên không đổi họ model.

## Dựng lại

Chạy trên máy đã đăng nhập provider. Các lệnh `group add` **thay** group cùng
id nếu đã tồn tại.

```sh
# 0) expose model WorkBuddy mà ladder GLM dùng ở cuối
magpie provider models workbuddy-ai +glm-5.3
magpie provider models workbuddy-ai +glm-5.3-flash

# 1) Main — Leader / phiên chính
magpie group add "Main" \
  models=autoclaw/zaicoding_glm-5.3,autoclaw/zai_glm-5.3-flash,autoclaw/zai_auto-fast,autoclaw/zai_auto,opencode-zen/glm-5.3-flash-free,workbuddy-ai/glm-5.3,workbuddy-ai/glm-5.3-flash \
  routing=order stays=auto
magpie group set main levels=low,high,max
magpie group rule add main use=autoclaw/zai_glm-5.3-flash compact

# 2) Code — Coder, cùng cấu trúc Main nhưng DeepSeek
magpie group add "Code" \
  models=workbuddy-ai/deepseek-v4.1-flash,opencode-zen/deepseek-v4.1-flash-free,workbuddy-ai/deepseek-v4.1-flash-sg \
  routing=order stays=auto
magpie group set code levels=low,high,max
magpie group rule add code use=opencode-zen/deepseek-v4.1-flash-free compact

# 3) GLM — group riêng của agent Leader
magpie group add "GLM" \
  models=autoclaw/zaicoding_glm-5.3,autoclaw/zai_glm-5.3-flash,autoclaw/zai_auto-fast,autoclaw/zai_auto,opencode-zen/glm-5.3-flash-free,workbuddy-ai/glm-5.3,workbuddy-ai/glm-5.3-flash \
  routing=order stays=auto
magpie group set glm levels=low,high,max

# 4) DeepSeek — Tester; id phải là `deepseek`, tên hiển thị đổi sau
magpie group add deepseek \
  models=workbuddy-ai/deepseek-v4.1-flash,opencode-zen/deepseek-v4.1-flash-free,workbuddy-ai/deepseek-v4.1-flash-sg \
  routing=order stays=turn
magpie group set deepseek name="DeepSeek V4.1 Flash"

# 5) trỏ hai app về Main
magpie opencode group/main
magpie openchamber group/main
```

Agent: chép nội dung [Phụ lục](#phụ-lục-leadermd) vào
`~/.config/opencode/agents/leader.md`; `coder.md` và `tester.md` giữ nguyên
prompt hiện có, chỉ đổi dòng `model:` như bảng phía trên.

## Kiểm tra

```sh
magpie group main          # 7 model GLM + 1 rule compact
magpie group code          # 3 model DeepSeek + 1 rule compact
magpie group glm           # 7 model GLM, không rule
magpie group deepseek      # 3 model DeepSeek, không rule
magpie groups              # tổng hợp + agent nào dùng

grep -H '^model:' ~/.config/opencode/agents/{leader,coder,tester}.md
magpie opencode            # magpie/group/main
magpie openchamber         # magpie/group/main
```

Agent đọc model lúc khởi động: **mở phiên mới** sau khi sửa `model:`. Thay đổi
group có hiệu lực ngay ở lượt kế tiếp, không cần restart gateway.

## Cảnh báo

- `scripts/setup-groups.sh --force` (và `finish.sh`, vì nó gọi `--force`) sẽ
  **tạo lại `group/main` và `group/code` theo ladder mặc định của repo**, không
  theo snapshot này. Nó không đụng `group/glm` hay `group/deepseek`, nhưng
  Main/Code sẽ mất cấu hình hiện tại. Muốn giữ thì đừng chạy `--force`, hoặc
  chạy lại mục [Dựng lại](#dựng-lại).
- `scripts/setup-opencode.sh` không ghi đè file agent đã có, nên `leader.md`,
  `coder.md`, `tester.md` đang chỉnh tay sẽ được giữ nguyên.
- **OpenChamber không nhận biến thể `#high`**: `magpie openchamber group/main#high`
  bị từ chối. Phiên OpenChamber chạy `group/main` ở mức effort mặc định; muốn
  `high` thì dùng OpenCode CLI (agent `leader.md` giữ `group/glm#high`), hoặc
  pin `:high` vào member của group.
- Không commit `~/.config/magpie/plugin-auth.json`, `web-key`, hay bất kỳ key
  nào. Tài liệu này chỉ chứa tên model và thứ tự routing.

## Phụ lục: `leader.md`

Chép nguyên khối dưới vào `~/.config/opencode/agents/leader.md`.

````markdown
---
description: Leader — GLM 5.3 (AutoClaw trước, WorkBuddy sau), toàn quyền như Build. Viết plan, điều phối Coder (DeepSeek) và Tester (DeepSeek), review cuối và duyệt
mode: primary
model: magpie/group/glm#high
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

Bạn là **Leader**. Bạn dùng GLM 5.3 (AutoClaw trước, rồi Zen free, cuối cùng mới
sang WorkBuddy). Bạn là người duy nhất trong
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
làm. Việc kiểm tra do **Tester** (DeepSeek) làm. Bạn ghi plan trong
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
không lẫn với plan cũ. Plan phải đủ chi tiết để một người mới đọc là làm được,
gồm:

1. **Mục tiêu** — kết quả cuối cùng user nhận được.
2. **Phạm vi** — làm gì, và **không** làm gì.
3. **Hiện trạng** — file/hàm/API liên quan, kèm đường dẫn và số dòng nếu có.
4. **Các bước thay đổi** — theo đúng thứ tự thực hiện. Mỗi bước ghi rõ:
   - file nào, sửa/thêm/xoá gì;
   - lý do;
   - chỗ nào dễ ảnh hưởng code khác.
5. **Hợp đồng dữ liệu** — kiểu dữ liệu, request/response, schema, format file
   nếu có.
6. **Tiêu chí nghiệm thu** — kiểm tra được, không mơ hồ. Ví dụ: "gọi
   `POST /products?q=ao` trả 200 và đúng 2 kết quả", không phải "chạy đúng".
7. **Lệnh kiểm tra** — test, lint, typecheck, build (đúng lệnh của project).
8. **Trường hợp biên & rủi ro** — input rỗng, lỗi mạng, quyền, dữ liệu cũ, ...
9. **Ngoài phạm vi** — những gì Coder không được đụng vào.

Nếu sau này plan phải đổi, cập nhật lại file plan và nói rõ với user.

### 4. Giao Coder

Dùng tool `subagent` với `agent: "coder"`. Subagent có context mới, nên phải
truyền đủ:

```
Project root: <đường dẫn tuyệt đối>
Plan: <đường dẫn tuyệt đối tới file plan> — đọc toàn bộ trước khi làm.
Chỉ đọc đúng file plan này. Bỏ qua mọi plan khác trong .opencode/plans/.
Nhiệm vụ: triển khai đúng plan, đúng thứ tự, không mở rộng phạm vi.
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
