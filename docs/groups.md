# Routing group — bảy group đang dùng

Group là nhiều model mà agent chọn như **một**. Agent trỏ vào `group/main`; gateway
quyết định model nào trả lời từng lượt, và tự chuyển model kế tiếp khi model hiện tại
hỏng, hết quota hoặc bị chặn.

## Định nghĩa

Bảy group. Sáu group đầu dùng `routing=order`, `effort=auto`, classifier
`opencode-zen/jev-1.13-free`, **không group nào có rule**; `main`/`leader`/`coder` mở
levels `low,high,max`, ba tester chỉ `high`. `group/free` là group riêng của
billion-context: không classifier, không levels, chỉ để việc nén gọi một phát.

### `group/main` — chat thường ngày

`stays=session` để hội thoại bám một tài khoản, prompt cache còn giá trị.

```sh
magpie group add "Main" \
  models=freepi/deepseek-v4.1-flash,workbuddy-ai/hy4flash-free,agy-cli/gemini-3.8-flash,agy-cli/gemini-2.5-flash-lite,autoclaw/zai_glm-5.3-flash,workbuddy-ai/glm-5.3-flash \
  routing=order stays=session
magpie group set main levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
# máy tham chiếu đang TẮT group này: magpie group off main (gateway trả not_found_error)
```

### `group/leader` — OpenChamber: plan + điều phối

`stays=turn`; hai model Xingchi đứng đầu (viết plan), Opus và DeepSeek SG dự phòng.

```sh
magpie group add "Leader" \
  models=xingchi/gpt-6-astra,xingchi/gpt-6.1-sol,agy-cli/claude-opus-4-6-thinking,workbuddy-ai/deepseek-v4.1-flash-sg \
  routing=order stays=turn
magpie group set leader levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

### `group/coder` — viết code theo plan

```sh
magpie group add "Coder" \
  models=freepi/deepseek-v4.1-flash:high \
  routing=order stays=turn
magpie group set coder levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

### `group/tester` — kiểm tra, chạy test

```sh
magpie group add "Tester" \
  models=freepi/deepseek-v4.1-flash:high,agnes/agnes-3.0-flash:high,workbuddy-ai/glm-5.3-flash \
  routing=order stays=turn
magpie group set tester levels=high classifier=opencode-zen/jev-1.13-free effort=auto
```

### `group/tester-2` — tester độc lập, chạy song song

Dùng pool khác Tester để hai bên không giành cùng một quota.

```sh
magpie group add "Tester 2" \
  models=workbuddy-ai/hy4flash-free:high,agnes/agnes-3.0-flash:high,agy-cli/gemini-3.8-flash:high,autoclaw/zai_glm-5.3-flash \
  routing=order stays=turn
magpie group set tester-2 levels=high classifier=opencode-zen/jev-1.13-free effort=auto
```

### `group/tester-3` — tester thứ ba, soi hợp đồng dữ liệu

```sh
magpie group add "Tester 3" \
  models=autoclaw/zai_glm-5.3-flash,agy-cli/gemini-3.8-flash,kilo/reflection/beam-free:high,workbuddy-ai/hy4flash-free:high \
  routing=order stays=turn
magpie group set tester-3 levels=high classifier=opencode-zen/jev-1.13-free effort=auto
```

### `group/free` — chỉ cho việc nén của billion-context

Không classifier, không levels, không `stays`: mỗi lần nén là một request độc lập, chọn
model free nhanh nhất còn sống. Đo 6 request song song, mỗi provider một model.

```sh
magpie group add "free" \
  models=cline/cline-free/solar-mini4,kilo/baidu/ernie-5.5-flash-preview:free,kiro/claude-haiku-4.5,openrouter/openrouter/free,workbuddy-ai/hy4flash-free \
  routing=order
```

Bảng đo và lý do chọn nằm trong [`billion-context.md`](billion-context.md).

### Provider đang tắt

`qoder`, `antigravity`, `copilot` và `opencode-zen-free` tắt vì không nằm trong group nào.
`kilo` **bật** vì `group/tester-3` dùng `kilo/reflection/beam-free`; `kiro`, `cline`,
`openrouter` bật vì `group/free` cần. `aihubmix` bật nhưng 36 model `-free` chỉ trả câu
từ chối (tài khoản chưa nạp tiền) — đừng đưa vào group nào. `opencode-zen` vẫn bật nhưng **chỉ**
giữ `jev-1.13-free` làm classifier, không phải rung fallback: script đọc danh sách đang
expose rồi bỏ mọi model khác, nên model free mới của Zen không tự lọt vào.

Group đã bỏ khỏi định nghĩa (`code`, `glm`, `deepseek`) được `setup-groups.sh --force`
xoá bằng `magpie group rm`, vì `group add` không dọn group thừa.

## Vì sao như vậy

**Chia group theo vai.** Leader, Coder và ba Tester là năm vai khác nhau, nên mỗi vai
một group thay vì dùng rule `intent` trong một group chung: classifier có thể đoán sai,
còn group riêng thì lượt nào cũng bắt đầu đúng model. Cách này cũng cho ba tester chạy
song song mà không tranh nhau một ladder.

**Thứ tự model.**

- `main`: FreePi trước (free 15k token/ngày), rồi Hy4 flash (free, 1M), Gemini 3.8
  Flash, Gemini 2.5 Flash-Lite, GLM-5.3 Flash của AutoClaw, cuối là WorkBuddy
  GLM-5.3-Flash. **Group đang tắt trên máy tham chiếu** vì FreePi đầu ladder hay 429.
- `leader`: hai model Xingchi trước (viết plan), Opus và DeepSeek SG dự phòng.
- `coder`: FreePi DeepSeek ở `high` — đủ mạnh cho code, không tốn quota WorkBuddy.
- `tester`: FreePi → Agnes → WorkBuddy GLM-5.3-Flash.
- `tester-2`: Hy4 → Agnes → Gemini 3.8 → AutoClaw GLM.
- `tester-3`: AutoClaw GLM → Gemini 3.8 → Kilo beam-free → Hy4.

`routing=order` nghĩa là model đầu trả lời; chỉ khi nó không trả lời được mới sang model
sau.

**`stays`.** `session` giữ một tài khoản suốt phiên → prompt cache còn giá trị, rẻ và
nhanh; dùng cho chat. `turn` cho phép đổi model mỗi lượt; dùng cho pipeline
Leader → Coder → Tester.

**`levels`.** Agent được chọn `low`, `high`, `max`; model nào không có mức đó thì magpie
gửi mức gần nhất. Ba tester chỉ mở `high` vì đó là mức chúng luôn dùng.

**`effort=auto` + `classifier`.** Mỗi lượt, model nhỏ `opencode-zen/jev-1.13-free` đọc
yêu cầu và chọn mức reasoning thay vì agent luôn dùng một mức. Rẻ hơn cho câu hỏi ngắn,
vẫn sâu cho việc khó. Classifier chỉ là model *phụ*: nó không nằm trong ladder, không
hiện ra cho agent chọn.

**Không rule.** Ảnh và nén hội thoại đã có đường riêng: ảnh do agent gửi thẳng model đọc
được ảnh, còn nén hội thoại do `billion-context` lo (xem
[`billion-context.md`](billion-context.md)) chứ không dựa vào rule `compact` của gateway.

## Sửa group

```sh
magpie group main                      # xem định nghĩa hiện tại
magpie group leader
magpie groups                          # danh sách + agent nào dùng

magpie group set main models+=freepi/deepseek-v4.1-flash   # thêm vào cuối
magpie group set main models-=autoclaw/zai_glm-5.3-flash   # bỏ
magpie group set leader stays=session                      # đổi cách giữ hội thoại
magpie group set main levels=low,medium,high,max
magpie group set main effort=agent                         # tắt classifier, để agent tự chọn
magpie group set main classifier=opencode-zen/jev-1.13-free

magpie group rule main                    # rule đang có, đánh số
magpie group rule add main use=… tokens=200k
magpie group rule rm main 2
magpie group rm coder                     # xoá group
```

Lưu ý: `magpie group add <tên đã dùng>` **thay** group đó. `scripts/setup-groups.sh`
chỉ thay khi có `--force`; `finish.sh` gọi với `--force` vì nó là nguồn định nghĩa.

## Kiểm tra

```sh
magpie group main | head -20
magpie groups
magpie claude group/main      # nếu có Claude Code
magpie opencode group/main
```

Agent đọc model lúc khởi động — mở phiên mới để thấy thay đổi.
