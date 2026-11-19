# Leader + pipeline review/reviewplan (cập nhật 2026-11-18)

Tài liệu này ghi lại **cấu hình chuẩn trong repo** cho pipeline 7 agent:

```
Leader → Review (brief hướng) → Leader duyệt → [task lớn: Reviewplan DIRECTION]
       → Review (plan) → Reviewplan (PLAN) → Coder → Tester ∥ Tester 2 ∥ Tester 3
       → Reviewplan (AUDIT) → Leader → User duyệt → Coder commit/push + dọn plan
```

`scripts/setup-groups.sh` là nguồn định nghĩa group; `config/agents/*.md` là nguồn
định nghĩa agent. Máy nào lệch thì chạy lại hai script đó — đừng sửa tay
`~/.config/magpie`. Trạng thái thật luôn xem bằng `magpie groups` và
`grep '^model:' ~/.config/opencode/agents/*.md`.

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
       Review — viết plan 13 mục (cùng session)
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
       Coder (commit + push + xoá .opencode/plans/<slug>)
```

- **Leader không đọc file, không shell, không sửa gì.** Nó chỉ có `question` và
  sáu subagent: `review`, `reviewplan`, `coder`, `tester`, `tester2`, `tester3`.
  Mọi thông tin về codebase do `review`/`reviewplan` mang về. Leader tách yêu cầu
  thành `R1..Rn`, dán vào mọi prompt, kiểm lại ở brief/plan/audit; mỗi prompt có
  `Skill: <id>`, `Skill: tự chọn` hoặc `Skill: không` để agent tự nạp skill. Agent lỗi thì Leader tự
  gọi lại hoặc chuyển việc cho agent còn làm được, không dừng pipeline.
- **Review** là người duy nhất viết plan. Nó khảo sát codebase, ghi bằng chứng
  `file:line`, trả **brief hướng** (~20 dòng) rồi dừng. Leader duyệt brief (task
  lớn thì Reviewplan gác bằng `MODE: DIRECTION`), sau đó Review viết plan 13 mục
  trong **cùng session**, tự chạy cổng chất lượng rồi báo Leader.
- **Reviewplan** có ba mode. `DIRECTION` (chỉ task lớn): gác brief hướng, kiểm
  `file:line` có thật, hướng giải quyết từng `R`, lý do loại phương án khác, phạm
  vi; trả `GO` / `STEER` / `CẦN ĐIỀU TRA`, **chỉ nêu vấn đề, không viết hướng
  thay Review**. `PLAN`: kiểm chứng độc lập plan của Review; thấy sai thì **tự sửa
  plan** (chỉ file plan), tự kiểm lại, rồi báo Leader. `AUDIT`: sau khi ba tester
  ĐẠT, đối chiếu `git diff` với plan, soi phạm vi, secret, log, debug, test rỗng,
  chạy lại lệnh test chính.
- **Coder** chỉ đọc đúng file plan được giao, làm đúng thứ tự, chạy lệnh kiểm tra
  từng bước. Plan sai thì dừng, báo `file:dòng`, không tự chế.
- **Ba tester** chạy song song trong một lượt, ba góc nhìn, không thấy nhau.
- **Commit/push chỉ xảy ra sau khi user duyệt**, trừ khi project tự quy định khác
  (`AGENTS.md` yêu cầu tự động commit + push sau verify — brief phải ghi rõ). Leader
  giao Coder commit, push, rồi xoá thư mục plan trong cùng một lượt. Push lỗi thì giữ plan.

### Vòng lặp

| Vòng | Ai làm | Tối đa | Hết vòng thì |
|---|---|---|---|
| Hướng | Reviewplan `DIRECTION` gác brief; Leader duyệt/steer | 2 brief, 2 lần gác | Dừng, hỏi user |
| Plan | Reviewplan kiểm plan; nếu cần dữ kiện thì Review điều tra bổ sung rồi Reviewplan sửa | 2 vòng | Dừng, báo user, giữ plan |
| Code | Coder sửa theo lỗi tester/audit | 3 vòng | Dừng, báo user, giữ plan |

Brief và vòng sửa brief không tính vào 2 vòng plan. Gác hướng tối đa 2 lần/task
(lần đầu và một lần sau STEER); quá thì dừng, hỏi user. Reviewplan được tự sửa
plan tối đa 2 lần trong một vòng plan; tự sửa không tính là một vòng, nhưng sửa
xong vẫn không đạt thì lần đó tính là hết một vòng.

### Session

`config/agents/leader.md` mở đầu bằng **Luật cứng — một session mỗi group**: mỗi
`group/*` chỉ phục vụ một session sống tại một thời điểm; trước mọi lần gọi
`subagent`, Leader in ledger 6 dòng, không gọi khi group đang chạy, và truyền
`sessionID` nếu đã có. Chưa có thì **bỏ hẳn tham số**, không ghi `(mới)`. Idle không
phải kết thúc — chỉ mở session mới khi session cũ đã kết thúc hẳn; không chắc thì coi
như còn sống.

Khi `review` đang lâu, Leader được giao việc khác cho `reviewplan`, `coder` hoặc
tester — miễn đúng vai trò của họ — thay vì mở thêm một `review`. Ba tester vẫn chạy
song song vì là ba group khác nhau; trong một vòng, mỗi tester gọi một lần, vòng
code sau gọi lại cả ba. Khi có nhiều việc độc lập, Leader có thể chạy `review` và
`reviewplan` song song (hai group khác nhau); cùng một plan vẫn tuần tự brief → plan →
PLAN → AUDIT.

Khi chạy song song, Leader giữ **khóa tài nguyên**: chỉ một agent dùng
`chrome-devtools` tại một thời điểm (`tester3` sở hữu UI; `reviewplan` AUDIT chỉ mở
khi `tester3` rảnh; `coder` chỉ self-check trước handoff); mỗi tester chỉ tạo file test
riêng `<slug>.testerN.test.*`; DB/port/test suite dùng chung thì xếp hàng.

`group/leader` cũng chỉ được có một session: đừng mở OpenChamber và một phiên Leader
OpenCode cùng lúc nếu cả hai dùng `group/leader`.

### Phát hiện lỗi thì giao ai

| Tình huống | Xử lý |
|---|---|
| Review tự kiểm fail, hoặc thiếu dữ kiện | Review tự sửa/điều tra lại; vẫn thiếu thì Leader hỏi user |
| Reviewplan thấy plan sai nhưng tự xác minh được | Reviewplan tự sửa plan + tự kiểm lại |
| Reviewplan cần điều tra sâu hơn | Leader giao Review điều tra bổ sung → Reviewplan sửa (1 vòng plan) |
| Reviewplan STEER hướng | Leader follow-up **cùng session review** để sửa brief/plan; không mở session mới |
| Reviewplan CẦN ĐIỀU TRA | Leader follow-up cùng session review để điều tra thêm, rồi Reviewplan PLAN |
| Agent lỗi | Gọi lại cùng session 2 lần (chờ session cũ dừng hẳn nếu đang chạy) → chỉ khi session cũ kết thúc mới mở session mới 1 lần; không chắc thì coi như còn sống → chuyển việc cho agent còn làm được → báo user kèm lỗi nguyên văn |
| Coder thấy plan sai giữa chừng | Dừng, báo `file:dòng` → Leader giao Reviewplan sửa plan → Coder làm tiếp |
| Tester fail do code | Coder sửa, kèm lỗi nguyên văn của cả ba tester |
| Tester fail do plan | Reviewplan sửa plan → Coder làm lại (1 vòng code) |
| Tester fail do test rỗng/sai | Coder viết lại test theo mục Test plan |
| Audit cuối fail | Coder hoặc Reviewplan tùy loại lỗi; còn vòng thì sửa, hết thì báo user |
| Hết 2 vòng plan / 3 vòng code | Không ai sửa nữa; Leader dừng, báo user, giữ plan |

## Agent

| Agent | File | Mode | Model | Quyền |
|---|---|---|---|---|
| Leader | `~/.config/opencode/agents/leader.md` | `primary` | `magpie/group/leader#max` | Chỉ `question` + 6 subagent; **deny** read/glob/grep/edit/shell/webfetch/websearch |
| Review | `~/.config/opencode/agents/review.md` | `subagent` | `magpie/group/review` | Đọc + shell đọc; **chỉ ghi** `.opencode/plans/**` |
| Reviewplan | `~/.config/opencode/agents/reviewplan.md` | `subagent` | `magpie/group/reviewplan` | Đọc + shell đọc/test; **chỉ ghi** `.opencode/plans/**` |
| Coder | `~/.config/opencode/agents/coder.md` | `subagent` | `magpie/group/coder` | Sửa source theo plan; không gọi subagent, không hỏi |
| Tester | `~/.config/opencode/agents/tester.md` | `subagent` | `magpie/group/tester` | Chạy test, không sửa code Coder |
| Tester 2 | `~/.config/opencode/agents/tester2.md` | `subagent` | `magpie/group/tester-2` | Tester độc lập, chạy song song |
| Tester 3 | `~/.config/opencode/agents/tester3.md` | `subagent` | `magpie/group/tester-3` | Soi hợp đồng dữ liệu + regression |

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
`Skill: <id>`, `Skill: tự chọn` hoặc `Skill: không`; subagent gọi tool `skill` với
đúng id trước khi làm. `tự chọn`: agent đọc danh sách skill của nó, chọn id khớp việc
đang làm và ghi tên skill đã nạp ở đầu báo cáo. Bảng chọn skill nằm trong `config/agents/leader.md` mục "Điều phối skill".
Cả bảy file agent đều có mục `## Skill` để nhắc điều này.

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
```

Quy tắc khớp **cuối cùng thắng**; rule rộng đặt trước, ngoại lệ đặt sau. Leader
không có rule `question` nào nên vẫn hỏi user được. Nếu Leader cần đọc file, nó
phải giao `review` hoặc `reviewplan` — không có đường vòng.

`review`/`reviewplan` có cùng cấu trúc: deny `edit *`, rồi allow
`.opencode/plans/**` và `**/.opencode/plans/**`. Nhờ vậy chúng sửa plan được nhưng
không đụng source.

## Plan của Review phải chứa gì

Coder là subagent có context mới, chỉ đọc đúng một file plan. Plan không phải bản
mô tả mà là **bản giao việc copy-paste được**, gồm 13 mục cố định
(`config/agents/review.md` mục 2.2). Ba luật cứng:

1. Plan **chứa code**: hàm mới là code hoàn chỉnh, file mới là toàn bộ nội dung,
   chỗ sửa là cặp khối `TÌM` (nguyên văn hiện tại) / `THAY` (sau khi sửa).
2. Mọi khẳng định về code hiện tại kèm `file:line` + trích nguyên văn.
3. Không để chỗ nào Coder phải tự quyết định thiết kế.

Trước khi báo Leader, Review tự chạy cổng chất lượng (mục 2.6): `grep -F` lại từng
khối `TÌM`, `test -f` từng đường dẫn, đối chiếu lệnh mục 10 với manifest/CI.
Reviewplan sau đó mở lại từng file và kiểm tra độc lập; plan trượt thì nó sửa
hoặc trả `CẦN ĐIỀU TRA`.

## Kiến trúc group

Chín group, mỗi vai một group (định nghĩa chuẩn trong `scripts/setup-groups.sh`):

| Group | Dùng cho | Model | Cấu hình |
|---|---|---|---|
| `group/leader` | Leader | `xingchi/gpt-6.1-sol:high` → FreePi6 → Opus → DeepSeek SG | `order`, `turn`, levels `low,high,max`, classifier |
| `group/review` | Review | FreePi DeepSeek V4.1 Flash `high` → DeepSeek SG `high` → Hy4 `high` | `order`, `turn`, levels `none,low,high,max`, classifier jev |
| `group/reviewplan` | Reviewplan | FreePi5 DeepSeek V4.1 Flash `high` → DeepSeek SG `high` → Hy4 `high` | `order`, `turn`, levels `none,low,high,max`, classifier jev |
| `group/coder` | Coder | FreePi `high` → DeepSeek SG `high` | `order`, `turn`, levels `low,high,max` |
| `group/tester` | Tester | FreePi4 → GLM WorkBuddy | `order`, `turn`, levels `low,high,max` |
| `group/tester-2` | Tester 2 | FreePi2 → Hy4 → GLM AutoClaw | `order`, `turn`, levels `low,high,max` |
| `group/tester-3` | Tester 3 | FreePi3 → Kiro Haiku → GLM AutoClaw → Gemini 3.8 → Hy4 → DeepSeek SG | `order`, `turn`, levels `low,high,max` |
| `group/main` | chat thường ngày (OpenCode) | FreePi → Hy4 → Gemini → Gemini Lite → GLM AutoClaw → GLM WorkBuddy | `order`, `session`, levels `low,high,max` |
| `group/free` | nén của billion-context | Particle-1 free: Kilo → Cline → OpenRouter → Groq → NVIDIA | `rotate`, `auto`, không classifier |

`group/main` **đang bật** trên máy tham chiếu và là model mặc định của OpenCode; tắt
tạm bằng `magpie group off main` (gateway trả not found cho tới khi bật lại).

### `group/review` và `group/reviewplan`

```sh
magpie group review
magpie group reviewplan
```

- `routing=order`, `stays=turn`; `review` dùng `freepi/deepseek-v4.1-flash:high` →
  `workbuddy-ai/deepseek-v4.1-flash-sg:high` → `workbuddy-ai/hy4flash-free:high`;
  `reviewplan` dùng `freepi5/deepseek-v4.1-flash:high` → hai bậc WorkBuddy như trên.
- Levels `none,low,high,max` (magpie mở levels khi đặt `effort=auto`; freepi không
  expose mức reasoning nhưng vẫn ghim `:high`), classifier
  `opencode-zen/jev-1.13-free`, `effort=auto`.
- Repo đã có ba bậc; thêm bằng
  `magpie group set review models+=<provider/model>`.
- `scripts/setup-groups.sh` **chỉ tạo khi thiếu**; `--force` không reset hai group
  này, nên `finish.sh` không xoá ladder tự thêm.

Review đọc nhiều file nên tốn quota; FreePi chỉ có 15.000 credit/ngày, nên
`reviewplan` dùng tài khoản FreePi5 thay vì giành slot với `review`. Khi thêm bậc,
nên đặt một model khác family ở cuối ladder để failover thật sự.

## Vì sao cấu hình như vậy

- **Leader chỉ điều phối** để mọi kết luận về code đều có người chịu trách nhiệm
  đọc file thật, và Leader không tự sửa rồi tự duyệt.
- **Brief trước, plan sau** — Review trả brief hướng rồi dừng; Leader duyệt (task
  lớn thì Reviewplan `DIRECTION` gác) trước khi Review viết 13 mục. Sai hướng lộ
  ra sau ~20 dòng thay vì sau cả plan.
- **Review viết plan, Reviewplan kiểm plan** — tách người viết khỏi người chấm.
  Reviewplan được sửa plan để không phải đốt một vòng chỉ vì lỗi chính tả/đường
  dẫn; nhưng mọi sửa đều ghi phụ lục để Leader biết.
- **Reviewplan audit cuối** thay vì Leader: Leader không đọc được `git diff`, và
  người đã duyệt plan là người phù hợp nhất để kiểm code có đúng plan không.
- **Ba tester song song** vì ba góc nhìn khác nhau, không thấy nhau nên không
  neo theo kết luận của nhau.
- **`stays=turn`** cho pipeline để mỗi bước có thể đổi model; `stays=session` cho
  main để prompt cache còn giá trị.
- **Không rule**: ảnh do agent gửi thẳng model đọc ảnh; nén hội thoại do
  billion-context lo ([`billion-context.md`](billion-context.md)).

## Dựng lại

Chạy `bash scripts/setup-groups.sh` (thêm `--force` để tạo lại bảy group cố định;
`review`/`reviewplan` chỉ tạo khi thiếu). Tương đương thủ công:

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
`magpie opencode group/main`, `magpie openchamber group/leader`,
`magpie opencode small magpie/workbuddy-ai/hy4flash-free`.

## Kiểm tra

```sh
magpie groups
magpie group review
magpie group reviewplan
magpie group leader

grep -H '^model:' ~/.config/opencode/agents/{leader,review,reviewplan,coder,tester,tester2,tester3}.md
magpie opencode            # magpie/group/main, small magpie/workbuddy-ai/hy4flash-free
magpie openchamber         # magpie/group/leader
```

Agent đọc model lúc khởi động: **mở phiên mới** sau khi sửa `model:`. Thay đổi
group có hiệu lực ngay ở lượt kế tiếp, không cần restart gateway.

## Cảnh báo

- `scripts/setup-groups.sh --force` (và `finish.sh`, vì nó gọi `--force`) tạo lại
  bảy group cố định và xoá `code`/`glm`/`deepseek` còn sót. Nó **không** reset
  `review`/`reviewplan`; muốn reset hai group này thì `magpie group rm review`,
  `magpie group rm reviewplan` rồi chạy lại script.
- `--force` cũng tạo lại `group/main` ở trạng thái bật. Trên máy tham chiếu group này
  đang bật và là model mặc định của OpenCode; chỉ tắt tay khi cần.
- `scripts/setup-opencode.sh` không ghi đè file agent đã có. Máy đã có
  `leader.md` cũ thì phải xoá/đổi tên trước, hoặc sửa tay; nếu không, bản mới
  không được cài.
- **Mức reasoning của OpenChamber chọn trong model picker**, lưu ở
  `defaultVariant` / `lastUsedEfforts` của
  `~/.config/openchamber/preferences.json`. Đặt mặc định `high`; `max` chỉ dùng
  cho việc khó vì sinh gấp ~2.7 lần token output. `leader.md` giữ
  `group/leader#max` cho OpenCode CLI.
- Không commit `~/.config/magpie/plugin-auth.json`, `web-key`, hay bất kỳ key nào.

## Phụ lục: file agent

Bản đang chạy nằm trong repo, không chép lại vào tài liệu này để khỏi lệch:

- [`leader.md`](../config/agents/leader.md)
- [`review.md`](../config/agents/review.md)
- [`reviewplan.md`](../config/agents/reviewplan.md)
- [`coder.md`](../config/agents/coder.md)
- [`tester.md`](../config/agents/tester.md)
- [`tester2.md`](../config/agents/tester2.md)
- [`tester3.md`](../config/agents/tester3.md)

`scripts/setup-opencode.sh` copy cả bảy vào `~/.config/opencode/agents/`.
