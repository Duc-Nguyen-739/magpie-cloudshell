# Leader + routing hiện tại (cập nhật 2026-11-16)

Tài liệu này ghi lại **cấu hình đang chạy trên máy này**: pipeline 5 agent
`Leader → Coder → Tester ∥ Tester 2 ∥ Tester 3`, model của từng agent, và các
routing group phía sau.
Từ bản này, `scripts/setup-groups.sh` tạo đúng thứ tự dưới đây; chạy `--force`
vẫn thay group hiện có nên đọc [Cảnh báo](#cảnh-báo) trước.

Môi trường: magpie `0.1.4291`, OpenCode + OpenChamber, Linux headless.

## Pipeline

```
User → Leader (plan, group/leader)
          │
          ▼
       Coder (code, group/coder)
          │
          ├───────────────┬───────────────┐
          ▼               ▼               ▼
       Tester          Tester 2        Tester 3
    (group/tester)  (group/tester-2) (group/tester-3)
          │               │               │
          └───────┬───────┴───────────────┘
                  ├─ KHÔNG ĐẠT ─→ Coder (tối đa 3 vòng)
                  └─ ĐẠT ─→ Leader (review cuối) → Duyệt
```

- Leader viết plan kỹ thuật chi tiết, giao Coder, giao ba Tester song song, kiểm tra
  cuối và duyệt.
- Tester báo **KHÔNG ĐẠT** → quay lại Coder, tối đa 3 vòng.
- Leader chỉ được gọi `coder`, `tester`, `tester2`, `tester3`; các subagent không được
  gọi agent khác hay hỏi người dùng.

### Plan của Leader phải chứa gì

Coder là subagent có context mới, chỉ đọc đúng một file plan. Vì vậy plan không
phải bản mô tả mà là **bản giao việc copy-paste được**, gồm 13 mục cố định
(`config/agents/leader.md` mục 3.2). Ba luật cứng:

1. Plan **chứa code**: hàm mới là code hoàn chỉnh, file mới là toàn bộ nội dung,
   chỗ sửa là cặp khối `TÌM` (nguyên văn hiện tại) / `THAY` (sau khi sửa).
2. Mọi khẳng định về code hiện tại kèm `file:line` + trích nguyên văn, không diễn
   giải bằng lời.
3. Không để chỗ nào Coder phải tự quyết định thiết kế.

Trước khi giao, Leader tự chạy cổng chất lượng (mục 3.6): `grep -F` lại từng khối
`TÌM` xem có khớp đúng file thật, `test -f` từng đường dẫn, đối chiếu lệnh trong
mục 10 với manifest/CI. Plan trượt cổng thì viết lại, không giao.

## Agent

| Agent | File | Mode | Model | Quyền |
|---|---|---|---|---|
| Leader | `~/.config/opencode/agents/leader.md` | `primary` | `magpie/group/leader#max` | Chỉ gọi `coder`, `tester`, `tester2`, `tester3` |
| Coder | `~/.config/opencode/agents/coder.md` | `subagent` | `magpie/group/coder` | Không gọi subagent, không hỏi |
| Tester | `~/.config/opencode/agents/tester.md` | `subagent` | `magpie/group/tester` | Không gọi subagent, không hỏi |
| Tester 2 | `~/.config/opencode/agents/tester2.md` | `subagent` | `magpie/group/tester-2` | Không gọi subagent, không hỏi |
| Tester 3 | `~/.config/opencode/agents/tester3.md` | `subagent` | `magpie/group/tester-3` | Không gọi subagent, không hỏi |

Dòng `model:` chính xác:

```yaml
# leader.md
model: magpie/group/leader#max

# coder.md
model: magpie/group/coder

# tester.md
model: magpie/group/tester

# tester2.md
model: magpie/group/tester-2

# tester3.md
model: magpie/group/tester-3
```

`#max` là mức reasoning gửi cho model đang phục vụ; model nào không có `max`
thì magpie gửi mức gần nhất. OpenCode CLI dùng được `#max`; OpenChamber thì
không (xem [Cảnh báo](#cảnh-báo)).

## Kiến trúc group

Sáu group, mỗi vai một group:

| Group | Dùng cho | Model | Cấu hình |
|---|---|---|---|
| `group/leader` | OpenChamber + Leader (OpenCode CLI) | DeepSeek SG `max` → Opus (2) | `order`, `stays=turn`, `effort=auto` + classifier |
| `group/main` | chat thường ngày (OpenCode) | FreePi → Hy4 → Gemini → GLM AutoClaw → GLM WorkBuddy (5) | `order`, `stays=session`, `effort=auto` + classifier |
| `group/coder` | Coder | FreePi `high` (1) | `order`, `stays=turn`, `effort=auto` + classifier |
| `group/tester` | Tester | FreePi → Agnes → GLM AutoClaw (3) | `order`, `stays=turn`, levels `high` |
| `group/tester-2` | Tester 2 | Hy4 → Kilo → Gemini → Agnes → GLM (5) | `order`, `stays=turn`, levels `high` |
| `group/tester-3` | Tester 3 | Gemini → GLM → Hy4 (3) | `order`, `stays=turn`, levels `high` |

Leader và Coder trỏ group riêng; không còn `group/code` dùng chung. OpenChamber gửi
model của phiên (`group/leader`), nên model trong `leader.md` chỉ áp dụng ở OpenCode
CLI/TUI. Định nghĩa đầy đủ từng group: [`groups.md`](groups.md).

### `group/leader` — plan + điều phối

```sh
magpie group leader
```

- `routing=order`, `stays=turn`, `levels=low,high,max`
- `effort=auto` + classifier `opencode-zen/jev-1.13-free`
- `workbuddy-ai/deepseek-v4.1-flash-sg:max` → `agy-cli/claude-opus-4-6-thinking`
- không rule

Ý đồ: DeepSeek SG ở `max` viết plan; Opus dự phòng khi WorkBuddy hết quota.
`stays=turn` để mỗi bước pipeline có thể đổi model.

### `group/coder` — Coder

- `freepi/deepseek-v4.1-flash:high`, `stays=turn`, levels `low,high,max`, không rule.
- FreePi free 15k token/ngày; cạn thì group không còn rung — Coder báo lỗi, Leader
  chuyển việc sang Tester hoặc chờ reset.

### `group/tester`, `group/tester-2`, `group/tester-3`

Ba group độc lập để ba tester chạy song song không tranh quota. Levels chỉ `high`.
Ladder xem bảng trên hoặc [`groups.md`](groups.md).

## Vì sao cấu hình như vậy

- **Mỗi vai một group** thay vì rule `intent`: classifier có thể đoán sai, group
  riêng thì lượt nào cũng bắt đầu đúng model.
- **`stays=session` cho main** để prompt cache còn giá trị; **`stays=turn`** cho
  pipeline vì mỗi bước cần model khác.
- **`effort=auto` + classifier jev** chọn low/high/max theo yêu cầu; classifier là
  model phụ, không vào ladder.
- **Không rule**: ảnh do agent gửi thẳng model đọc ảnh; nén hội thoại do
  billion-context lo ([`billion-context.md`](billion-context.md)).
- **Levels**: main/leader/coder mở `low,high,max`; tester chỉ `high`.

## Dựng lại

Chạy `bash scripts/setup-groups.sh` (thêm `--force` để tạo lại cả sáu). Script tự bỏ
model chưa có, nên chạy được sau khi đăng nhập 1–2 provider. Tương đương thủ công:

```sh
magpie group add "Leader" \
  models=workbuddy-ai/deepseek-v4.1-flash-sg:max,agy-cli/claude-opus-4-6-thinking \
  routing=order stays=turn
magpie group set leader levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto

magpie group add "Coder" models=freepi/deepseek-v4.1-flash:high routing=order stays=turn
magpie group set coder levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto

magpie group add "Tester" \
  models=freepi/deepseek-v4.1-flash:high,agnes/agnes-3.0-flash:high,autoclaw/zai_glm-5.3-flash \
  routing=order stays=turn
magpie group set tester levels=high classifier=opencode-zen/jev-1.13-free effort=auto

magpie group add "Tester 2" \
  models=workbuddy-ai/hy4flash-free:high,kilo/reflection/beam-free:high,agy-cli/gemini-3.8-flash:high,agnes/agnes-3.0-flash:high,autoclaw/zai_glm-5.3-flash \
  routing=order stays=turn
magpie group set tester-2 levels=high classifier=opencode-zen/jev-1.13-free effort=auto

magpie group add "Tester 3" \
  models=agy-cli/gemini-3.8-flash:high,autoclaw/zai_glm-5.3-flash,workbuddy-ai/hy4flash-free:high \
  routing=order stays=turn
magpie group set tester-3 levels=high classifier=opencode-zen/jev-1.13-free effort=auto

magpie group add "Main" \
  models=freepi/deepseek-v4.1-flash,workbuddy-ai/hy4flash-free,agy-cli/gemini-3.8-flash,autoclaw/zai_glm-5.3-flash,workbuddy-ai/glm-5.3-flash \
  routing=order stays=session
magpie group set main levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

Trỏ agent: `magpie opencode group/main`, `magpie openchamber group/leader`,
`magpie opencode small magpie/workbuddy-ai/hy4flash-free`.

## Kiểm tra

```sh
magpie group leader
magpie group main
magpie group coder
magpie group tester
magpie groups              # tổng hợp + agent nào dùng

grep -H '^model:' ~/.config/opencode/agents/{leader,coder,tester,tester2,tester3}.md
magpie opencode            # magpie/group/main, small magpie/workbuddy-ai/hy4flash-free
magpie openchamber         # magpie/group/leader
```

Agent đọc model lúc khởi động: **mở phiên mới** sau khi sửa `model:`. Thay đổi
group có hiệu lực ngay ở lượt kế tiếp, không cần restart gateway.

## Cảnh báo

- `scripts/setup-groups.sh --force` (và `finish.sh`, vì nó gọi `--force`) sẽ
  **tạo lại cả sáu group** theo ladder trong script và xoá `code`/`glm`/`deepseek`
  còn sót. Muốn giữ group tự thêm tay thì đừng chạy `--force`, hoặc chạy lại mục
  [Dựng lại](#dựng-lại).
- `scripts/setup-opencode.sh` không ghi đè file agent đã có, nên `leader.md`,
  `coder.md`, `tester.md`, `tester2.md`, `tester3.md` đang chỉnh tay sẽ được giữ nguyên.
- **Mức reasoning của OpenChamber chọn trong model picker**, lưu ở
  `defaultVariant` / `lastUsedEfforts` của
  `~/.config/openchamber/preferences.json`. Đặt mặc định `high`; `max` chỉ dùng
  cho việc khó vì nó sinh gấp ~2.7 lần token output. Agent `leader.md` giữ
  `group/leader#max` cho OpenCode CLI.
- Không commit `~/.config/magpie/plugin-auth.json`, `web-key`, hay bất kỳ key
  nào. Tài liệu này chỉ chứa tên model và thứ tự routing.

## Phụ lục: `leader.md`

Bản đang chạy nằm trong [`config/agents/leader.md`](../config/agents/leader.md) — repo
giữ đúng bản trên máy, không chép lại vào tài liệu này để khỏi lệch. Bốn subagent:
[`coder.md`](../config/agents/coder.md), [`tester.md`](../config/agents/tester.md),
[`tester2.md`](../config/agents/tester2.md), [`tester3.md`](../config/agents/tester3.md).

`scripts/setup-opencode.sh` copy cả năm vào `~/.config/opencode/agents/`.
