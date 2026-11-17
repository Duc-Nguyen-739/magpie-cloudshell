# Routing group — chín group đang dùng

Group là nhiều model mà agent chọn như **một**. Agent trỏ vào `group/main`; gateway
quyết định model nào trả lời từng lượt, và tự chuyển model kế tiếp khi model hiện tại
hỏng, hết quota hoặc bị chặn.

## Định nghĩa

Chín group. Tám group dùng `routing=order`, `effort=auto`, classifier
`opencode-zen/jev-1.13-free`, **không group nào có rule**. `main`/`leader`/`coder` và
ba tester mở levels `low,high,max`; `review`/`reviewplan` mở
`none,low,high,max` (Freepi không expose mức reasoning nhưng magpie vẫn mở levels khi
đặt `effort=auto`). `group/free` là group riêng của billion-context: plain,
`routing=rotate`, chỉ để việc nén gọi một phát.

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

`stays=turn`; `gpt-6.1-sol` ghim `:high` đứng đầu (viết plan), Opus và DeepSeek SG
dự phòng. `gpt-6-astra` đã bỏ khỏi group vì pool upstream của Xingchi trả 503 — xem
[`providers.md`](providers.md).

```sh
magpie group add "Leader" \
  models=xingchi/gpt-6.1-sol:high,agy-cli/claude-opus-4-6-thinking,workbuddy-ai/deepseek-v4.1-flash-sg \
  routing=order stays=turn
magpie group set leader levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

### `group/review` — khảo sát codebase và viết plan

`stays=turn` để sau này thêm bậc failover mà không phải đổi kiểu giữ hội thoại.
Levels `none,low,high,max` (magpie mở levels khi đặt `effort=auto`; FreePi không
expose mức reasoning nhưng vẫn ghim `:high`), classifier
`opencode-zen/jev-1.13-free` + `effort=auto` như các group khác.

```sh
magpie group add "Review" \
  models=freepi/deepseek-v4.1-flash:high,workbuddy-ai/deepseek-v4.1-flash-sg \
  routing=order stays=turn
magpie group set review levels=none,low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

Người dùng tự thêm model: `magpie group set review models+=<provider/model>`. Nên
đặt model khác family ở cuối ladder để failover thật sự khi FreePi cạn quota.

### `group/reviewplan` — kiểm chứng/sửa plan và audit cuối

Cùng cấu hình với `group/review` (freepi:high → DeepSeek SG, classifier jev);
hiện chưa có model khác family nên việc kiểm chứng chưa độc lập hoàn toàn. Thêm
model khác family khi có điều kiện.

```sh
magpie group add "Reviewplan" \
  models=freepi/deepseek-v4.1-flash:high,workbuddy-ai/deepseek-v4.1-flash-sg \
  routing=order stays=turn
magpie group set reviewplan levels=none,low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

`scripts/setup-groups.sh` chỉ tạo hai group này khi thiếu; `--force` **không** reset
chúng, để ladder người dùng tự thêm không bị `finish.sh` xoá. Muốn reset:
`magpie group rm review` (hoặc `reviewplan`) rồi chạy lại script.

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
  models=freepi/deepseek-v4.1-flash,workbuddy-ai/glm-5.3-flash \
  routing=order stays=turn
magpie group set tester levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

### `group/tester-2` — tester độc lập, chạy song song

Dùng pool khác Tester để hai bên không giành cùng một quota.

```sh
magpie group add "Tester 2" \
  models=workbuddy-ai/hy4flash-free,agnes/agnes-3.0-flash,agy-cli/gemini-3.8-flash,autoclaw/zai_glm-5.3-flash \
  routing=order stays=turn
magpie group set tester-2 levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

### `group/tester-3` — tester thứ ba, soi hợp đồng dữ liệu

```sh
magpie group add "Tester 3" \
  models=kiro/claude-haiku-4.5,kilo/reflection/beam-free,autoclaw/zai_glm-5.3-flash,agy-cli/gemini-3.8-flash,workbuddy-ai/hy4flash-free \
  routing=order stays=turn
magpie group set tester-3 levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

### `group/free` — chỉ cho việc nén của billion-context

Không classifier, không levels, không `stays`: mỗi lần nén là một request độc lập, chọn
model free nhanh nhất còn sống. Đo 6 request song song, mỗi provider một model.

```sh
magpie group add "free" \
  models=kilo/particle-ai/particle-1:free,cline/particle-ai/particle-1:free,openrouter/particle-ai/particle-1:free \
  routing=rotate
```

Bảng đo và lý do chọn nằm trong [`billion-context.md`](billion-context.md).

### Provider đang tắt

`aihubmix`, `copilot`, `agnes` và `opencode-zen-free` đang tắt vì không nằm trong group
nào; `qoder`/`antigravity` chỉ còn record trong `providers.json` và không hiện vì thiếu
plugin. `kilo` **bật** vì `group/tester-3` dùng `kilo/reflection/beam-free` và `group/free`
dùng `particle-1:free`; `kiro`, `cline`, `openrouter` bật vì `group/free` cần. `aihubmix`
nếu bật thì 36 model `-free` chỉ trả câu từ chối (tài khoản chưa nạp tiền) — đừng đưa vào
group nào. `opencode-zen` vẫn bật nhưng **chỉ**
giữ `jev-1.13-free` làm classifier, không phải rung fallback: script đọc danh sách đang
expose rồi bỏ mọi model khác, nên model free mới của Zen không tự lọt vào.

Group đã bỏ khỏi định nghĩa (`code`, `glm`, `deepseek`) được `setup-groups.sh --force`
xoá bằng `magpie group rm`, vì `group add` không dọn group thừa.

## Vì sao như vậy

**Chia group theo vai.** Leader, Review, Reviewplan, Coder và ba Tester là bảy vai khác
nhau, nên mỗi vai một group thay vì dùng rule `intent` trong một group chung: classifier
có thể đoán sai, còn group riêng thì lượt nào cũng bắt đầu đúng model. Cách này cũng cho
ba tester chạy song song mà không tranh nhau một ladder.

**Thứ tự model.**

- `main`: FreePi trước (free 15k token/ngày), rồi Hy4 flash (free, 1M), Gemini 3.8
  Flash, Gemini 2.5 Flash-Lite, GLM-5.3 Flash của AutoClaw, cuối là WorkBuddy
  GLM-5.3-Flash. **Group đang tắt trên máy tham chiếu** vì FreePi đầu ladder hay 429.
- `leader`: `xingchi/gpt-6.1-sol:high` trước (đo được 2,0 s so với 4,6 s khi để
  mặc định), Opus và DeepSeek SG dự phòng.
- `review`/`reviewplan`: FreePi DeepSeek V4.1 Flash. Review đọc nhiều file nên cần
  theo dõi quota; Reviewplan nên có model khác family khi thêm bậc.
- `coder`: FreePi DeepSeek ở `high` — đủ mạnh cho code, không tốn quota WorkBuddy.
- `tester`: FreePi → WorkBuddy GLM-5.3-Flash (Agnes đang tắt nên bỏ khỏi ladder).
- `tester-2`: Hy4 → Agnes → Gemini 3.8 → AutoClaw GLM.
- `tester-3`: Kiro Haiku → Kilo beam-free → AutoClaw GLM → Gemini 3.8 → Hy4.

`routing=order` nghĩa là model đầu trả lời; chỉ khi nó không trả lời được mới sang model
sau.

**`stays`.** `session` giữ một tài khoản suốt phiên → prompt cache còn giá trị, rẻ và
nhanh; dùng cho chat. `turn` cho phép đổi model mỗi lượt; dùng cho pipeline
Leader → Review → Reviewplan → Coder → Tester.

**`levels`.** Phần lớn group mở `low`, `high`, `max`; `review`/`reviewplan` mở thêm
`none` (magpie tự mở levels khi đặt `effort=auto`). Model nào không có mức được chọn
thì magpie gửi mức gần nhất.

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
Ngoại lệ: `review`/`reviewplan` chỉ được tạo khi thiếu, `--force` không reset — để
ladder người dùng tự thêm không bị xoá. Reset hai group này bằng `magpie group rm`
rồi chạy lại script.

## Kiểm tra

```sh
magpie group main | head -20
magpie groups
magpie claude group/main      # nếu có Claude Code
magpie opencode group/main
```

Agent đọc model lúc khởi động — mở phiên mới để thấy thay đổi.
