# Routing group — tám group mẫu + group/compress

Group là nhiều model mà agent chọn như **một**. OpenCode và OpenChamber trỏ vào
`group/leader`; gateway quyết định model nào trả lời từng lượt, và tự chuyển model kế
tiếp khi model hiện tại hỏng, hết quota hoặc bị chặn.

> **Model trong group do bạn tự chọn.** Các ladder trong tài liệu này là **ví dụ**;
> repo không đồng bộ ladder từ máy tham chiếu và `finish.sh` không reset group đã có.

## Định nghĩa

Tám group mẫu. Tất cả dùng `routing=order`, `effort=auto`, classifier
`opencode-zen/jev-1.13-free`, **không group nào có rule**. `main`/`leader`/`coder` và
ba tester mở levels `low,high,max`; `review`/`reviewplan` mở
`none,low,high,max` (FreePi không expose mức reasoning nhưng magpie vẫn mở levels khi
đặt `effort=auto`). `group/compress` là group riêng của billion-context, do người dùng
tạo: plain, `routing=rotate`, `stays=off`, chỉ để việc nén gọi một phát.

### `group/main` — chat thường ngày (ví dụ)

`stays=session` để hội thoại bám một tài khoản, prompt cache còn giá trị. Máy tham
chiếu hiện **tắt** group này; OpenCode/OpenChamber dùng `group/leader`.

```sh
magpie group add "Main" \
  models=freepi/deepseek-v4.1-flash,workbuddy-ai/hy4flash-free,agy-cli/gemini-3.8-flash,agy-cli/gemini-2.5-flash-lite,autoclaw/zai_glm-5.3-flash,workbuddy-ai/glm-5.3-flash \
  routing=order stays=session
magpie group set main levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
# bật/tắt: magpie group on main · magpie group off main
```

### `group/leader` — OpenChamber: plan + điều phối

`stays=turn`; `gpt-6.1-sol` ghim `:high` đứng đầu (viết plan), FreePi6, Opus và
DeepSeek SG dự phòng. `gpt-6-astra` đã bỏ khỏi group vì pool upstream của Xingchi
trả 503 — xem [`providers.md`](providers.md).

```sh
magpie group add "Leader" \
  models=xingchi/gpt-6.1-sol:high,freepi6/deepseek-v4.1-flash,agy-cli/claude-opus-4-6-thinking,workbuddy-ai/deepseek-v4.1-flash-sg \
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
  models=freepi/deepseek-v4.1-flash:high,workbuddy-ai/deepseek-v4.1-flash-sg:high,workbuddy-ai/hy4flash-free:high \
  routing=order stays=turn
magpie group set review levels=none,low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

Repo đã có ba bậc; thêm bằng `magpie group set review models+=<provider/model>`. Nên
đặt model khác family ở cuối ladder để failover thật sự khi FreePi cạn quota.

### `group/reviewplan` — kiểm chứng/sửa plan và audit cuối

Dùng tài khoản FreePi5 để không giành slot với `review`; hai bậc WorkBuddy dự phòng.
Cùng levels/classifier với `group/review`; hiện chưa có model khác family nên việc
kiểm chứng chưa độc lập hoàn toàn. Thêm model khác family khi có điều kiện.

```sh
magpie group add "Reviewplan" \
  models=freepi5/deepseek-v4.1-flash:high,workbuddy-ai/deepseek-v4.1-flash-sg:high,workbuddy-ai/hy4flash-free:high \
  routing=order stays=turn
magpie group set reviewplan levels=none,low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

`scripts/setup-groups.sh` chỉ tạo hai group này khi thiếu; `--force` **không** reset
chúng. `finish.sh` không dùng `--force`, nên ladder người dùng tự thêm không bị xoá.
Muốn reset:
`magpie group rm review` (hoặc `reviewplan`) rồi chạy lại script.

### `group/coder` — viết code theo plan

FreePi chính `high`, DeepSeek SG `high` dự phòng.

```sh
magpie group add "Coder" \
  models=freepi/deepseek-v4.1-flash:high,workbuddy-ai/deepseek-v4.1-flash-sg:high \
  routing=order stays=turn
magpie group set coder levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

### `group/tester` — kiểm tra, chạy test

FreePi4 để ba tester chạy song song không giành slot; WorkBuddy GLM dự phòng.

```sh
magpie group add "Tester" \
  models=freepi4/deepseek-v4.1-flash,workbuddy-ai/glm-5.3-flash \
  routing=order stays=turn
magpie group set tester levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

### `group/tester-2` — tester độc lập, chạy song song

FreePi2 đứng đầu; WorkBuddy và AutoClaw dự phòng. Dùng pool khác Tester để hai bên
không giành cùng một quota.

```sh
magpie group add "Tester 2" \
  models=freepi2/deepseek-v4.1-flash,workbuddy-ai/hy4flash-free,autoclaw/zai_glm-5.3-flash \
  routing=order stays=turn
magpie group set tester-2 levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

### `group/tester-3` — tester thứ ba, soi hợp đồng dữ liệu

FreePi3 đứng đầu; Kiro, AutoClaw, Gemini và hai bậc WorkBuddy dự phòng.

```sh
magpie group add "Tester 3" \
  models=freepi3/deepseek-v4.1-flash,kiro/claude-haiku-4.5,autoclaw/zai_glm-5.3-flash,agy-cli/gemini-3.8-flash,workbuddy-ai/hy4flash-free,workbuddy-ai/deepseek-v4.1-flash-sg \
  routing=order stays=turn
magpie group set tester-3 levels=low,high,max classifier=opencode-zen/jev-1.13-free effort=auto
```

### `group/compress` — chỉ cho việc nén của billion-context

Do **người dùng tự tạo**, không có trong `setup-groups.sh`. Không classifier, `stays=off`:
mỗi lần nén là một request độc lập, chọn model free nhanh nhất còn sống. Trên máy tham
chiếu:

```sh
magpie group add "compress" \
  models=nvidia/nvidia/nemotron-3.5-super-vl-120b-a12b,openrouter/particle-ai/particle-1:free,kilo/particle-ai/particle-1:free,workbuddy-ai/hy4flash-free \
  routing=rotate stays=off
```

`levels` của group này do magpie tự suy từ các model, không phải tay đặt — đừng cố ghim
levels cho nó. Config billion-context chỉ trỏ `magpie/group/compress`; xem
[`billion-context.md`](billion-context.md).

### Provider đang tắt

`aihubmix`, `copilot` và `agnes` đang tắt vì không nằm trong group
nào; `opencode-zen-free` **bật** (free tier hoạt động lại 2026-11-25); `qoder`/`antigravity` chỉ còn record trong `providers.json` và không hiện vì thiếu
plugin. `kilo` **bật** vì `group/compress` dùng `particle-1:free`; `openrouter` và
`nvidia` bật vì `group/compress` cần. `kiro`, `cline`, `groq` **bật**; `agy-cli` **không cài** trên máy
tham chiếu (repo vẫn cài như tuỳ chọn). `aihubmix` nếu bật thì 36 model `-free` chỉ trả
câu từ chối (tài khoản chưa nạp tiền) — đừng đưa vào group nào. `opencode-zen` vẫn bật
nhưng **chỉ** giữ `jev-1.13-free` làm classifier, không phải rung fallback: script đọc
danh sách đang expose rồi bỏ mọi model khác, nên model free mới của Zen không tự lọt vào.

Group đã bỏ khỏi định nghĩa (`code`, `glm`, `deepseek`, `free`) được
`setup-groups.sh --force` xoá bằng `magpie group rm`, vì `group add` không dọn group thừa.

## Vì sao như vậy

**Chia group theo vai.** Leader, Review, Reviewplan, Coder và ba Tester là bảy vai khác
nhau, nên mỗi vai một group thay vì dùng rule `intent` trong một group chung: classifier
có thể đoán sai, còn group riêng thì lượt nào cũng bắt đầu đúng model. Cách này cũng cho
ba tester chạy song song mà không tranh nhau một ladder.

**Thứ tự model.**

- `main` (ví dụ): FreePi trước (free 15k token/ngày), rồi Hy4 flash (free, 1M),
  GLM-5.3 Flash của AutoClaw, cuối là WorkBuddy GLM-5.3-Flash. Nếu FreePi đầu ladder
  429 nhiều thì bỏ khỏi group hoặc tắt tạm bằng `magpie group off main`.
- `leader`: `xingchi/gpt-6.1-sol:high` trước (đo được 2,0 s so với 4,6 s khi để
  mặc định), FreePi6, Opus và DeepSeek SG dự phòng.
- `review`/`reviewplan`: FreePi DeepSeek V4.1 Flash; `reviewplan` dùng tài khoản
  FreePi5 để không giành slot với `review`. Review đọc nhiều file nên cần theo dõi
  quota; Reviewplan nên có model khác family khi thêm bậc.
- `coder`: FreePi DeepSeek ở `high` — đủ mạnh cho code, không tốn quota WorkBuddy.
- `tester`: FreePi2 → WorkBuddy DeepSeek SG (Agnes đang tắt nên bỏ khỏi ladder).
- `tester-2`: FreePi7 → AutoClaw GLM.
- `tester-3`: FreePi5 → AutoClaw GLM.

**Chia tài khoản FreePi.** Trên máy tham chiếu: `main`/`reviewplan` dùng FreePi chính
(15k credit/ngày), `review` FreePi4, `coder` FreePi3, `tester` FreePi2, `tester-2`
FreePi7, `tester-3` FreePi5, `leader` FreePi6. Nhờ vậy ba tester và review/reviewplan
chạy song song không giành một slot "one request at a time" của cùng tài khoản.

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
chỉ thay khi có `--force`; `finish.sh` và `bootstrap.sh` gọi **không** `--force` để
không reset ladder người dùng đã sửa. Ngoại lệ: `review`/`reviewplan` chỉ được tạo
khi thiếu, `--force` cũng không reset. Reset một group bằng `magpie group rm <id>`
rồi chạy lại script.

## Kiểm tra

```sh
magpie group main | head -20
magpie groups
magpie claude group/main      # nếu có Claude Code
magpie opencode group/main
```

Agent đọc model lúc khởi động — mở phiên mới để thấy thay đổi.
