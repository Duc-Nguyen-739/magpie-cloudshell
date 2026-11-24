# Leader + pipeline review/reviewplan (cập nhật 2026-11-24)

Tài liệu này ghi lại **cấu hình chuẩn trong repo** cho pipeline 7 agent. Đây là
pipeline của `CHANGE`; `CONSULT`/`PLAN`/`RELEASE` dừng ở điểm tương ứng, không chạy
toàn bộ:

```
Leader → Review (brief hướng) → Leader duyệt → [task lớn: Reviewplan DIRECTION]
       → Review (plan STANDARD/STRICT) → Reviewplan (PLAN) → Coder
       → các cổng bắt buộc: Tester ∥ Tester 2 ∥ Tester 3
       → Reviewplan (AUDIT) → Leader → User duyệt → Coder commit/push
       → dọn plan chỉ khi user duyệt riêng
```

`scripts/setup-groups.sh` là nguồn định nghĩa group; `config/agents/*.md` là nguồn
định nghĩa agent. Máy nào lệch thì chạy lại hai script đó — đừng sửa tay
`~/.config/magpie`. Trạng thái thật luôn xem bằng `magpie groups` và
`grep '^model:' ~/.config/opencode/agents/*.md`. Bảng model trong tài liệu này là
**cấu hình chuẩn của repo**; máy đang chạy có thể đã được chỉnh khác, nên đối chiếu
runtime trước khi kết luận.

## Pipeline

```
User → Leader (quyết định, group/leader)
          │
          ▼
       Review — brief hướng (khảo sát, group/review)
          │
          ▼
       Leader duyệt hướng ──(task lớn)──→ Reviewplan — MODE: DIRECTION
          │                                      │ GO / STEER
          │◄─────────────────────────────────────┘
          ▼
       Review — viết plan STANDARD/STRICT (phiên mới)
          │
          ▼
       Reviewplan — MODE: PLAN (kiểm chứng, tự sửa plan, group/reviewplan)
          │
          ▼
       Coder (code theo plan, group/coder)
          │
          ├───────────────┬───────────────┐
          ▼               ▼               ▼
       Tester          Tester 2        Tester 3
    (group/tester)  (group/tester-2) (group/tester-3)
          │               │               │
          └───────┬───────┴───────────────┘
                  ▼
       Reviewplan — MODE: AUDIT (audit cuối)
                  │
                  ▼
       Leader → User (báo kết quả, xin duyệt commit/push)
                  │
                  ▼
       Coder (commit/push; dọn plan chỉ khi duyệt riêng)
```

Luồng trên là mặc định của `CHANGE`. Ba tester là mặc định cho `CHANGE`; nếu plan
dùng chung DB/port hoặc `tester3` phải reset data thì chạy tuần tự theo Khóa tài
nguyên. Không giảm số cổng bắt buộc vì group bận/hết quota; thiếu cổng là `BLOCKED`.

- **Leader không sửa gì; shell chỉ read-only.** Nó có `question`, sáu
  subagent (`review`, `reviewplan`, `coder`, `tester`, `tester2`, `tester3`) và các
  MCP đọc còn hiện trong phiên. Mọi thông tin về codebase do `review`/`reviewplan`
  mang về. Leader chốt `task_mode` (`CONSULT`/`PLAN`/`CHANGE`/`RELEASE`), tách yêu
  cầu thành `R1..Rn`, dán vào mọi prompt, kiểm lại ở brief/plan/audit; mỗi prompt
  có `Skill: <id> (required|optional)`, `Skill: tự chọn` hoặc `Skill: không`.
- **Review** là người duy nhất viết plan. Nó khảo sát codebase, ghi bằng chứng
  `file:line`, trả **brief hướng** (~20 dòng) rồi dừng; `CONSULT` chỉ trả báo cáo,
  không tạo plan. Leader duyệt brief (task lớn thì Reviewplan gác bằng `MODE:
  DIRECTION`), sau đó Review viết plan **STANDARD** hoặc **STRICT** trong **phiên
  PLAN mới**, nhận brief đã duyệt qua handoff, tự chạy cổng chất lượng rồi báo
  Leader. Plan có `snapshot_id`, `plan_revision`, trạng thái từng bước.
- **Reviewplan** có ba mode. `DIRECTION` (chỉ task lớn): gác brief hướng, kiểm
  `file:line` có thật, hướng giải quyết từng `R`, lý do loại phương án khác, phạm
  vi; trả `GO` / `STEER` / `CẦN ĐIỀU TRA`, **chỉ nêu vấn đề, không viết hướng
  thay Review**. `PLAN`: kiểm chứng độc lập plan; **minor repair** (đường dẫn, tham
  chiếu, lệnh, lỗi cục bộ có bằng chứng) được tự sửa trong file plan; **major
  change** (hướng/AC/phạm vi/API/schema/dependency) phải trả về Review/Leader.
  `AUDIT`: sau khi mọi cổng bắt buộc `PASS`, đối chiếu `git diff`/`git diff
  --cached` với plan, soi phạm vi, secret, log, debug, test rỗng, chạy lại lệnh test
  chính; trả `PASS` / `FAIL` / `BLOCKED`.
- **Coder** chỉ đọc đúng file plan được giao, làm đúng thứ tự, chạy lệnh kiểm tra
  từng bước. Plan sai thì dừng, báo `file:dòng`, không tự chế. `CHANGE` triển khai;
  `RELEASE` chỉ commit/push/dọn plan theo đúng phạm vi đã duyệt.
- **Ba tester** chạy song song trong một lượt (trừ khi plan dùng chung DB/port — xem
  Khóa tài nguyên), ba coverage khác nhau, không thấy nhau: `functional` (Tester),
  `adversarial` (Tester2), `runtime` + `ui` khi bắt buộc (Tester3).
- **Commit/push chỉ xảy ra sau khi user duyệt**, trừ khi project tự quy định khác
  (`AGENTS.md` yêu cầu tự động commit + push sau verify — brief phải ghi rõ, và
  không được vượt lệnh “không commit” của task). Leader giao Coder commit, push;
  dọn plan là quyền riêng, không gộp mặc định. Push lỗi thì giữ plan.

### Vòng lặp

| Bộ đếm | Ai làm | Tối đa | Hết thì |
|---|---|---|---|
| `brief_attempt` | Review brief; Leader duyệt/steer | 2 (gồm lượt đầu) | Dừng, hỏi user |
| `direction_attempt` | Reviewplan `DIRECTION` | 2 (gồm lần đầu) | Dừng, hỏi user |
| `plan_attempt` | Review viết plan + Reviewplan kiểm | 2 (gồm lượt đầu) | Dừng, báo user, giữ plan |
| `plan_repairs` | Reviewplan sửa minor repair | 2/task | Dừng, báo user |
| `code_iteration` | Coder implement/sửa + các cổng test | 3 (gồm lượt đầu) | Dừng, báo user, giữ plan |
| `infra_retry` | Retry lỗi môi trường/model/413 | 1/thao tác | `BLOCKED`, báo user |

`plan_attempt` và `plan_repairs` độc lập. Sửa plan không mở vòng plan mới nhưng
không được dùng để lách giới hạn. `infra_retry` không làm mới các bộ đếm khác.
Thao tác có tác dụng phụ (ghi DB, commit, push) timeout phải kiểm trạng thái thực tế
trước khi retry; không chạy đôi.

### Session

`config/agents/leader.md` mở đầu bằng **luật Session — một group, một lượt thực thi**:
mỗi `group/*` chỉ có một lượt **đang chạy** tại một thời điểm; trước mọi lần gọi
`subagent`, Leader in dòng `LEDGER`. Không mở lượt thứ hai cùng group khi lượt cũ còn
chạy — hai lượt Review, Coder, Tester… cùng lúc đều có thể lỗi tài khoản. Nếu việc
mới ưu tiên hơn, chỉ dừng/không chờ việc cũ bằng công cụ hủy mà harness thực sự cung
cấp, rồi chờ trạng thái dừng được xác nhận mới mở lượt mới; không tự đoán là đã dừng.
**Mỗi lần gọi (mỗi turn/vòng) = session mới**: sau khi một agent trả báo cáo (kể cả
brief, plan, kết quả test), **lượt thực thi kết thúc và agent về idle** — không có
nghĩa session bị xóa hay mất khả năng tiếp tục. Theo chính sách pipeline này, không
tái sử dụng session đó: lần giao việc tiếp theo mở session mới, không truyền
`sessionID`. Trong cùng một vòng, nếu cần follow-up (STEER brief, sửa plan, sửa test,
retry lỗi), vẫn mở session mới với handoff đầy đủ. Không có ngoại lệ "nối cho nhanh".
Trạng thái ledger: `chạy`, `xong`, `lỗi`, `—`; ledger chỉ có giá trị trong lượt hiện
tại, handoff mang trạng thái sang lượt mới.

Lý do: FreePi giới hạn **kích thước request body** (~1,1 MB). Dùng lại một session
qua nhiều giai đoạn — nhất là `reviewplan` DIRECTION → PLAN → AUDIT — cộng dồn plan,
diff, test log và ảnh cho tới khi mọi lượt gửi đều trả **413 "This conversation is
too long"**. Đây là lựa chọn của pipeline, không phải hạn chế chung của OpenCode:
subagent vẫn có thể nhận lượt làm việc tiếp theo nếu được thiết kế như vậy.

Khi `review` đang lâu, Leader được giao việc khác cho `reviewplan`, `coder` hoặc
tester — miễn đúng vai trò của họ — thay vì mở thêm một `review`. Ba tester vẫn chạy
song song vì là ba group khác nhau; trong một vòng, mỗi tester gọi một lần cho một
snapshot (retry `BLOCKED` không tính); vòng code sau theo luật Session (mỗi vòng
session mới cho cả ba). Group khác nhau chưa chắc là tài khoản/capacity độc lập: khi
failover, hai group có thể cùng rơi vào một provider.

Khi có nhiều việc độc lập, Leader có thể chạy `review` và `reviewplan` song song (hai
group khác nhau); cùng một plan vẫn tuần tự brief → plan → PLAN → AUDIT. `magpie-sessions`
chỉ là transcript, không phải trạng thái chạy; không dùng nó để kết luận một lượt đã dừng.

Khi chạy song song, Leader giữ **khóa tài nguyên**: chỉ một agent dùng
`chrome-devtools` tại một thời điểm (`tester3` sở hữu UI; `reviewplan` AUDIT chỉ mở
khi `tester3` rảnh; `coder` chỉ self-check trước handoff); mỗi tester chỉ tạo file test
riêng `<slug>.testerN.test.*`; DB/port/test suite dùng chung thì xếp hàng.

`group/leader` cũng chỉ được có một lượt thực thi: đừng mở OpenChamber và một phiên
Leader OpenCode cùng lúc nếu cả hai dùng `group/leader`.

### Phát hiện lỗi thì giao ai

| Tình huống | Xử lý |
|---|---|
| Review tự kiểm fail, hoặc thiếu dữ kiện | Review tự sửa/điều tra lại; vẫn thiếu thì Leader hỏi user |
| Reviewplan thấy plan sai nhưng là minor repair | Reviewplan tự sửa plan + tự kiểm lại |
| Reviewplan thấy major change (hướng/AC/phạm vi/API/schema) | Không tự sửa; trả `CẦN ĐIỀU TRA`/`KHÔNG ĐẠT` để Leader quay lại Review |
| Reviewplan cần điều tra sâu hơn | Leader giao Review điều tra bổ sung → Reviewplan kiểm lại (1 vòng plan) |
| Reviewplan STEER hướng | Leader mở **session review mới** để sửa brief; không nối session cũ, không mở session brief thứ hai |
| Reviewplan CẦN ĐIỀU TRA | Theo luật Session, mở **session review mới** để điều tra thêm, rồi **session reviewplan mới** cho vòng PLAN kế |
| Agent lỗi | 413/context: mở session mới ngay với handoff rút gọn, `infra_retry=1`. Lỗi tạm thời: session mới, `infra_retry=1`; vẫn lỗi thì `BLOCKED`/chuyển việc nếu không mất cổng bắt buộc, rồi báo user kèm lỗi nguyên văn |
| Coder thấy plan sai giữa chừng | Dừng, báo `file:dòng` → Leader giao Reviewplan sửa minor repair → Coder làm tiếp |
| Tester `FAIL` do code | Coder sửa, kèm lỗi nguyên văn của các tester đã chạy |
| Tester `FAIL` do plan | Reviewplan sửa minor repair → Coder làm lại (1 vòng code); major change quay lại Review |
| Tester `FAIL` do test rỗng/sai | Tester đã viết test đó sửa test của chính nó (hoặc Coder nếu test nằm trong plan); chạy lại tester đó, không tính vòng code |
| Audit cuối `FAIL` | Coder hoặc Reviewplan tùy loại lỗi; còn vòng thì sửa, hết thì báo user |
| Audit `BLOCKED` | Retry hạ tầng 1 lần; vẫn thiếu bằng chứng thì dừng, báo user |
| Hết 2 vòng plan / 3 vòng code | Không ai sửa nữa; Leader dừng, báo user, giữ plan |

## Agent

| Agent | File | Mode | Model | Quyền |
|---|---|---|---|---|
| Leader | `~/.config/opencode/agents/leader.md` | `primary` | `magpie/group/leader#max` | `question` + 6 subagent + MCP đọc; **deny** read/glob/grep/edit/shell/webfetch/websearch/skill/execute |
| Review | `~/.config/opencode/agents/review.md` | `subagent` | `magpie/group/review` | Shell allowlist chỉ đọc; **chỉ ghi** `.opencode/plans/**`; deny chrome |
| Reviewplan | `~/.config/opencode/agents/reviewplan.md` | `subagent` | `magpie/group/reviewplan` | Shell deny-list lệnh phá huỷ; **chỉ ghi** `.opencode/plans/**` |
| Coder | `~/.config/opencode/agents/coder.md` | `subagent` | `magpie/group/coder` | Sửa source theo plan; deny sửa plan/force-push; không gọi subagent, không hỏi |
| Tester | `~/.config/opencode/agents/tester.md` | `subagent` | `magpie/group/tester` | Chỉ ghi test ownership `tester1`; deny chrome; không sửa source |
| Tester 2 | `~/.config/opencode/agents/tester2.md` | `subagent` | `magpie/group/tester-2` | Chỉ ghi test ownership `tester2`; deny chrome; không sửa source |
| Tester 3 | `~/.config/opencode/agents/tester3.md` | `subagent` | `magpie/group/tester-3` | Chỉ ghi test ownership `tester3`; lái browser; không sửa source |

Shell allowlist/deny-list là **best-effort**, không phải sandbox: shell chạy bằng
quyền user host và có thể bị lách bằng lệnh lồng. Không dùng nó thay cho môi trường
cách ly khi cần bảo vệ mạnh.

Dòng `model:` chính xác:

```yaml
# leader.md
model: magpie/group/leader#max

# review.md
model: magpie/group/review

# reviewplan.md
model: magpie/group/reviewplan

# coder.md
model: magpie/group/coder

# tester.md
model: magpie/group/tester

# tester2.md
model: magpie/group/tester-2

# tester3.md
model: magpie/group/tester-3
```

`review`/`reviewplan` không có hậu tố `#high` vì agent dùng variant mặc định;
group của chúng vẫn mở levels `none,low,high,max` và freepi đã ghim `:high` trong
ladder. `#max` của Leader chỉ dùng được trên OpenCode CLI/TUI; OpenChamber gửi
model của phiên (`group/leader`) và chọn mức trong model picker.

## Skill

Leader không tự nạp skill. Trong mỗi prompt giao việc, Leader thêm một dòng
`Skill: <id> (required|optional)`, `Skill: tự chọn` hoặc `Skill: không`; subagent gọi
tool `skill` với đúng id trước khi làm. `tự chọn`: agent đọc danh sách skill của nó,
chọn id khớp việc đang làm và ghi tên skill đã nạp ở đầu báo cáo. Bảng chọn skill nằm
trong `config/agents/leader.md` mục "Điều phối skill". Cả bảy file agent đều có mục
`## Skill` để nhắc điều này.

**Availability là runtime, không phải danh sách cứng:** chỉ id thật sự có trong
catalog của phiên mới nạp được. Skill optional thiếu: cảnh báo, làm tiếp. Skill
required theo luật project thiếu: `BLOCKED`, không tự cài skill hay sửa project
config. Hai ngoại lệ `magpie-sessions`/`magpie-quota` cũng chỉ dùng khi có trong
catalog.

### Quyền của Leader

Frontmatter `config/agents/leader.md` chặn ở mức tool, không chỉ ở prompt:

```yaml
permissions:
  - action: subagent
    resource: "*"
    effect: deny
  - action: subagent
    resource: "review"
    effect: allow
  - action: subagent
    resource: "reviewplan"
    effect: allow
  - action: subagent
    resource: "coder"
    effect: allow
  - action: subagent
    resource: "tester"
    effect: allow
  - action: subagent
    resource: "tester2"
    effect: allow
  - action: subagent
    resource: "tester3"
    effect: allow
  - action: read
    resource: "*"
    effect: deny
  - action: glob
    resource: "*"
    effect: deny
  - action: grep
    resource: "*"
    effect: deny
  - action: edit
    resource: "*"
    effect: deny
  - action: shell
    resource: "*"
    effect: deny
  - action: webfetch
    resource: "*"
    effect: deny
  - action: websearch
    resource: "*"
    effect: deny
  - action: skill
    resource: "*"
    effect: deny
  - action: execute
    resource: "*"
    effect: deny
```

Quy tắc khớp **cuối cùng thắng**; rule rộng đặt trước, ngoại lệ đặt sau. Leader
không có rule `question` nào nên vẫn hỏi user được. `shell` có thêm allowlist
read-only (git read, `sha1sum`, `grep`, `cat`, `ls`, `sed -n`, `gh run view`, `curl`
localhost) và `external_directory` mở `~/.config/opencode/**` + `/tmp/opencode/**`;
Leader chỉ spot-check, không sửa file. Cần đọc sâu/khảo sát thì giao `review` hoặc
`reviewplan`.

`review`/`reviewplan` có cùng cấu trúc: deny `edit *`, rồi allow
`.opencode/plans/**` và `**/.opencode/plans/**`. Nhờ vậy chúng sửa plan được nhưng
không đụng source. `review` có shell allowlist chỉ đọc; `reviewplan` có deny-list
best-effort cho lệnh phá huỷ. Cả hai đều deny skill `magpie-skills` và
`openchamber-extensions`; `review` deny `chrome-devtools`, `reviewplan` giữ cho AUDIT.

## Plan của Review phải chứa gì

Coder luôn có context mới, chỉ đọc đúng một file plan. Plan không phải bản mô tả
chung mà là **bản giao việc đủ để triển khai**, theo mẫu 13 mục
(`config/agents/review.md` mục 2.2), ở một trong hai mức:

- **STANDARD** (mặc định): chốt mục tiêu, phạm vi, thiết kế, hợp đồng dữ liệu, đơn
  vị sửa, test/AC, lệnh kiểm tra, rollback; dán code ở chỗ dễ hiểu sai. Coder được
  tự quyết chi tiết cục bộ trong ranh giới đã duyệt, không đổi API public/schema/
  dependency/auth/phạm vi/AC.
- **STRICT**: code đầy đủ, `TÌM`/`THAY` cho từng chỗ sửa; dùng cho migration,
  auth/quyền, dữ liệu không hoàn tác, API public hoặc khi user muốn copy-paste.

Cả hai mức: mọi khẳng định về code hiện tại kèm `file:line` + trích nguyên văn;
không để quyết định thiết kế mơ hồ; ghi `snapshot_id`, `plan_revision` và trạng thái
từng bước `PENDING`/`APPLIED`/`PARTIAL`/`BLOCKED`.

Trước khi báo Leader, Review tự chạy cổng chất lượng (mục 2.6): kiểm `TÌM` (STRICT),
`test -f` từng đường dẫn, đối chiếu lệnh mục 10 với manifest/CI. Reviewplan sau đó
mở lại từng file và kiểm tra độc lập; minor repair thì sửa, major change thì trả
`CẦN ĐIỀU TRA`/`KHÔNG ĐẠT` để quay lại Review.

## Kiến trúc group

Chín group, mỗi vai một group (định nghĩa chuẩn trong `scripts/setup-groups.sh`):

| Group | Dùng cho | Model | Cấu hình |
|---|---|---|---|
| `group/leader` | Leader + OpenCode + OpenChamber | FreePi6 `:max` → DeepSeek SG `:max` → `xingchi/gpt-6.1-sol` | `order`, `turn`, levels `low,high,max`, classifier |
| `group/review` | Review | FreePi4 DeepSeek V4.1 Flash `high` | `order`, `turn`, levels `high,max`, classifier jev |
| `group/reviewplan` | Reviewplan | FreePi DeepSeek V4.1 Flash `high` | `order`, `turn`, levels `high,max`, classifier jev |
| `group/coder` | Coder | FreePi3 `high` → DeepSeek SG `high` | `order`, `turn`, levels `low,high,max` |
| `group/tester` | Tester | FreePi2 → DeepSeek SG | `order`, `turn`, levels `low,high,max` |
| `group/tester-2` | Tester 2 | FreePi7 → GLM AutoClaw | `order`, `turn`, levels `low,high,max` |
| `group/tester-3` | Tester 3 | FreePi5 → GLM AutoClaw | `order`, `turn`, levels `low,high,max` |
| `group/main` | chat thường ngày (ví dụ) | FreePi → Hy4 → GLM AutoClaw → GLM WorkBuddy | `order`, `session`, levels `low,high,max` |
| `group/compress` | nén của billion-context | NVIDIA → OpenRouter → Kilo → Hy4 | `rotate`, `off`, không classifier |

Bảng trên là **trạng thái máy tham chiếu** (2026-11-22), không phải yêu cầu cài đặt:
model trong group do người dùng tự chọn. `group/main` hiện **tắt**; OpenCode và
OpenChamber đều dùng `group/leader`. Luôn kiểm `magpie groups`/`magpie group <tên>`
trước khi kết luận failover; không reset group về bảng này nếu user chưa yêu cầu.

### `group/review` và `group/reviewplan`

```sh
magpie group review
magpie group reviewplan
```

- `routing=order`, `stays=turn`; máy tham chiếu: `review` dùng
  `freepi4/deepseek-v4.1-flash:high`, `reviewplan` dùng
  `freepi/deepseek-v4.1-flash:high`.
- Levels `high,max` (magpie mở levels khi đặt `effort=auto`; FreePi không expose mức
  reasoning nhưng vẫn ghim `:high`), classifier `opencode-zen/jev-1.13-free`,
  `effort=auto`.
- Thêm bậc bằng `magpie group set review models+=<provider/model>`.
- `scripts/setup-groups.sh` **chỉ tạo khi thiếu**; `finish.sh` không dùng `--force`,
  nên không xoá ladder tự thêm.

Review đọc nhiều file nên tốn quota; FreePi chỉ có 15.000 credit/ngày, nên
`reviewplan` dùng tài khoản FreePi chính còn `review` dùng FreePi4 để không giành slot.
Khi thêm bậc, nên đặt một model khác family ở cuối ladder để failover thật sự.

## Vì sao cấu hình như vậy

- **Leader chỉ điều phối** để mọi kết luận về code đều có người chịu trách nhiệm
  đọc file thật, và Leader không tự sửa rồi tự duyệt.
- **Brief trước, plan sau** — Review trả brief hướng rồi dừng; Leader duyệt (task
  lớn thì Reviewplan `DIRECTION` gác) trước khi Review viết plan đầy đủ. Sai hướng lộ
  ra sau ~20 dòng thay vì sau cả plan.
- **Review viết plan, Reviewplan kiểm plan** — tách người viết khỏi người chấm.
  Reviewplan được sửa plan để không phải đốt một vòng chỉ vì lỗi chính tả/đường
  dẫn; nhưng mọi sửa đều ghi phụ lục để Leader biết.
- **Reviewplan audit cuối** thay vì Leader: Leader không đọc được `git diff`, và
  người đã duyệt plan là người phù hợp nhất để kiểm code có đúng plan không.
- **Ba tester song song** vì ba góc nhìn khác nhau, không thấy nhau nên không
  neo theo kết luận của nhau.
- **Một session một việc** vì FreePi giới hạn byte request body: session sống quá
  lâu qua nhiều giai đoạn sẽ 413; mở session mới + handoff rẻ hơn nhiều so với vòng
  retry không cứu được.
- **`stays=turn`** cho pipeline để mỗi bước có thể đổi model; `stays=session` cho
  main để prompt cache còn giá trị.
- **Không rule**: ảnh do agent gửi thẳng model đọc ảnh; nén hội thoại do
  billion-context lo ([`billion-context.md`](billion-context.md)).

## Dựng lại

Chạy `bash scripts/setup-groups.sh` (chỉ tạo group còn thiếu; thêm `--force` nếu
thật sự muốn tạo lại bảy group cố định). Cập nhật agent profile bằng
`bash scripts/setup-opencode.sh --sync --no-mcp`, rồi kiểm bằng
`python3 scripts/check-agents.py` và bộ test. Tương đương thủ công:

```sh
magpie group add "Review" \
  models=freepi/deepseek-v4.1-flash:high,workbuddy-ai/deepseek-v4.1-flash-sg:high,workbuddy-ai/hy4flash-free:high \
  routing=order stays=turn
magpie group set review levels=none,low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
magpie group add "Reviewplan" \
  models=freepi5/deepseek-v4.1-flash:high,workbuddy-ai/deepseek-v4.1-flash-sg:high,workbuddy-ai/hy4flash-free:high \
  routing=order stays=turn
magpie group set reviewplan levels=none,low,high,max classifier=opencode-zen/jev-1.13-free effort=auto

magpie group add "Leader" \
  models=xingchi/gpt-6.1-sol:high,freepi6/deepseek-v4.1-flash,agy-cli/claude-opus-4-6-thinking,workbuddy-ai/deepseek-v4.1-flash-sg \
  routing=order stays=turn
magpie group set leader levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

Các group còn lại giữ như [`groups.md`](groups.md). Trỏ agent:
`magpie opencode group/leader`, `magpie openchamber group/leader`,
`magpie opencode small default` (small model để mặc định).

## Kiểm tra

```sh
magpie groups
magpie group review
magpie group reviewplan
magpie group leader

grep -H '^model:' ~/.config/opencode/agents/{leader,review,reviewplan,coder,tester,tester2,tester3}.md
magpie opencode            # magpie/group/leader, small —
magpie openchamber         # magpie/group/leader, defaultAgent leader

python3 scripts/check-agents.py
python3 -m unittest discover -s tests -p 'test_*.py'
python3 scripts/sync-agents.py --check
```

Agent đọc model lúc khởi động: **mở phiên mới** sau khi sửa `model:`. Thay đổi
group có hiệu lực ngay ở lượt kế tiếp, không cần restart gateway. OpenCode V2 tự nạp
lại agent khi file đổi; phiên đang chạy vẫn giữ model/quyền của phiên hiện tại.

## Cảnh báo

- `scripts/setup-groups.sh --force` tạo lại sáu group cố định và xoá
  `code`/`glm`/`deepseek` còn sót. `finish.sh` và `bootstrap.sh` **không** dùng
  `--force`, nên không reset ladder người dùng đã sửa. Muốn reset một group:
  `magpie group rm <id>` rồi chạy lại script.
- `--force` cũng tạo lại `group/main` ở trạng thái bật. Trên máy tham chiếu group này
  đang tắt; OpenCode/OpenChamber dùng `group/leader`.
- `scripts/setup-opencode.sh` mặc định không ghi đè file agent đã có. Muốn cập nhật
  cả file đã có, dùng `bash scripts/setup-opencode.sh --sync --no-mcp`: script backup
  vào `~/.config/opencode/agents/backups/<timestamp>/`, giữ dòng `model:` cục bộ, ghi
  atomic từng file và không đụng group/MCP. Không nhúng `--sync` vào `finish.sh`:
  mỗi lần đăng nhập không nên ghi đè prompt người dùng đã sửa tay.
- `--sync` từ chối file target là symlink; kiểm source bằng `check-agents.py` trước
  khi ghi. Nếu target đã đổi ngoài dự kiến, dùng
  `--expected-manifest <file.json>` (map role → sha256) để abort cả batch thay vì ghi
  đè; wrapper chuyển tiếp cờ này cho `sync-agents.py`.
- **Mức reasoning của OpenChamber chọn trong model picker**, lưu ở
  `defaultVariant` / `lastUsedEfforts` của
  `~/.config/openchamber/preferences.json`. Đặt mặc định `high`; `max` chỉ dùng
  cho việc khó vì sinh gấp ~2.7 lần token output. `leader.md` giữ
  `group/leader#max` cho OpenCode CLI.
- Không commit `~/.config/magpie/plugin-auth.json`, `web-key`, hay bất kỳ key nào.

## Cập nhật 2026-11-24 — gate artifact, mode vận hành, MCP

Bản profile đang chạy trên máy tham chiếu từ 2026-11-24 bổ sung, so với pipeline mô tả
ở trên:

- **Mỗi lượt gọi subagent là session mới**, kể cả `review`/`reviewplan`; không truyền
  `sessionID`. Dùng tool `openchamber` (chỉ đọc) để kiểm trạng thái và báo cáo con:
  `session.list { children, withStatus }`, `session.status`, `session.messages`.
- **Block `GATE:`** trong mọi prompt giao việc (`decision_id`, `phase`, `agent`,
  `scope`, `R`, `expected`, `stop_if`, `artifact`, `artifact_revision`,
  `artifact_hash`) và `GATE_REPORT` ở báo cáo con. Plugin
  `config/plugins/leader-gate.js` đăng ký gate, giới hạn STEER theo `maxSteers`, và
  yêu cầu hash ở pha `PLAN`/`GATE`/`AUDIT`.
- **Artifact hash**: plan được freeze với dòng `artifact_hash: SELF`; tính bằng
  `python3 scripts/plan-hash.py <plan>` (helper trong repo, cài ở
  `~/.config/opencode/scripts/plan-hash.py`). Hash lệch → `BLOCKED`, không chấm tiếp.
- **Mode vận hành** `FAST` (mặc định), `SAFE` (auth/dữ liệu/hai kho), `MULTI` (≥2 task
  độc lập) — ghi `Mode:` vào mọi handoff. `FAST` vẫn giữ đủ cổng bắt buộc, chỉ song
  song thêm ở pha PREP.
- **Skill chỉ lấy từ repo đang làm** (`skills/` khai báo trong `opencode.json`) cộng
  `opencode`/`report`; cấm nạp skill thư viện magpie. Hai ngoại lệ là `magpie-sessions`
  (Leader được phép) và `magpie-quota` (khi có trong catalog). Mỗi dòng giao skill
  ghi `required` hoặc `optional`.
- **Quyền Leader**: `openchamber` được phép (chỉ đọc), `magpie-sessions_*` được phép;
  `magpie-web-search_*`/`cloudflare-docs_*`/`chrome-devtools_*` bị deny. Shell vẫn
  read-only, bổ sung `sha256sum`, `jq`, `python3 scripts/plan-hash.py`,
  `magpie tool analyze_image`.

## Phụ lục: file agent

Bản đang chạy nằm trong repo, không chép lại vào tài liệu này để khỏi lệch:

- [`leader.md`](../config/agents/leader.md)
- [`review.md`](../config/agents/review.md)
- [`reviewplan.md`](../config/agents/reviewplan.md)
- [`coder.md`](../config/agents/coder.md)
- [`tester.md`](../config/agents/tester.md)
- [`tester2.md`](../config/agents/tester2.md)
- [`tester3.md`](../config/agents/tester3.md)

`scripts/setup-opencode.sh` cài cả bảy vào `~/.config/opencode/agents/` (mặc định
chỉ file thiếu; `--sync` để cập nhật có backup).
