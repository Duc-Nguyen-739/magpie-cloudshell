# Routing group — ba group đang dùng

Group là nhiều model mà agent chọn như **một**. Agent trỏ vào `group/main`; gateway
quyết định model nào trả lời từng lượt, và tự chuyển model kế tiếp khi model hiện tại
hỏng, hết quota hoặc bị chặn.

## Định nghĩa

Ba group. `deepseek-v4.1-flash` (bản thường) và `workbuddy-ai/glm-5.3` đã bị provider bỏ
khỏi danh sách, nên không còn trong định nghĩa; `deepseek-v4.1-flash-sg` là bản duy nhất
còn serve và đứng đầu ladder.

`autoclaw/zai_auto` và `autoclaw/zai_auto-fast` đã bị bỏ khỏi mọi group: chúng chỉ có
**200K context** trong khi phần còn lại là 1M, nên giữ lại thì khai báo context của group
thành sai và một request dài rơi xuống chúng sẽ lỗi. Bỏ đi thì cả ba group đều 1M thật.

### `group/main` — chat thường ngày

```sh
magpie group add "Main" \
  models=workbuddy-ai/deepseek-v4.1-flash-sg,autoclaw/zai_glm-5.3-flash,autoclaw/zaicoding_glm-5.3,workbuddy-ai/glm-5.3-flash,workbuddy-ai/hy4free \
  routing=order stays=session

magpie group set main levels=low,high,max
magpie group set main classifier=opencode-zen/jev-1.13-free
magpie group set main effort=auto

magpie group rule add main use=workbuddy-ai/hy4free images
magpie group rule add main use=workbuddy-ai/hy4free,workbuddy-ai/glm-5.3-flash compact
```

### `group/code` — công việc code

Cùng ladder, `stays=turn` và 6 rule (nén hội thoại đứng đầu):

```sh
magpie group add "Code" \
  models=workbuddy-ai/deepseek-v4.1-flash-sg,autoclaw/zai_glm-5.3-flash,autoclaw/zaicoding_glm-5.3,workbuddy-ai/glm-5.3-flash,workbuddy-ai/hy4free \
  routing=order stays=turn
magpie group set code levels=low,high,max
magpie group set code classifier=opencode-zen/jev-1.13-free
magpie group set code effort=auto

# Đứng đầu để bước nén không bị rule intent giành mất. hy4free trước (free, 1M);
# hy4free lỗi hoặc bị limit thì nhảy sang GLM-5.3 Flash (cũng 1M, rẻ).
magpie group rule add code use=workbuddy-ai/hy4free,workbuddy-ai/glm-5.3-flash compact

magpie group rule add code use=workbuddy-ai/deepseek-v4.1-flash-sg \
  intent="asking for a detailed plan before any code is written (lên plan, lập kế hoạch chi tiết)"
magpie group rule add code use=workbuddy-ai/deepseek-v4.1-flash-sg \
  intent="writing, implementing or fixing code (viết code, code theo plan, implement, sửa code)"
magpie group rule add code use=autoclaw/zai_glm-5.3-flash,autoclaw/zaicoding_glm-5.3,workbuddy-ai/glm-5.3-flash \
  intent="running tests or checking the code just written, before it is finished (kiểm tra, test code vừa viết)"
magpie group rule add code use=workbuddy-ai/deepseek-v4.1-flash-sg \
  intent="final overall review of the finished code and releasing or publishing it (kiểm tra tổng thể lần cuối, duyệt, phát hành, release, ship)"
magpie group rule add code use=workbuddy-ai/hy4free images
```

### `group/glm` — Tester

Group riêng cho Tester để lượt test **luôn** bắt đầu bằng GLM, không phụ thuộc
classifier đoán đúng ý định. Đúng 3 model GLM 1M, không rule, không classifier:

```sh
magpie group add "GLM" \
  models=autoclaw/zai_glm-5.3-flash,autoclaw/zaicoding_glm-5.3,workbuddy-ai/glm-5.3-flash \
  routing=order stays=auto
magpie group set glm levels=low,high,max
```

`zaicoding_glm-5.3` đứng sau `zai_glm-5.3-flash` vì quota free của gói coding hay cạn
(upstream trả 429); để nó đầu ladder thì mỗi lượt Tester phải thử nó, ăn 429 rồi mới rơi
xuống model kế tiếp, tốn thêm một vòng mạng.

### Provider đang tắt

Không nằm trong group nào nên tắt hẳn: `kilo`, `qoder`, `opencode-zen-free`. Bật lại
bằng `magpie provider on <id>` khi cần thêm model ngoài ladder. `opencode-zen` vẫn bật
nhưng **chỉ** giữ `jev-1.13-free` làm classifier, không phải rung fallback: script đọc
danh sách đang expose rồi bỏ mọi model khác, nên model free mới của Zen không tự lọt vào.

Group đã bỏ khỏi định nghĩa (`deepseek`) được `setup-groups.sh --force` xoá bằng
`magpie group rm`, vì `group add` không dọn group thừa.

## Vì sao như vậy

**Thứ tự model.** Ladder đi theo đúng pipeline: DeepSeek trước (Leader + Coder), GLM
sau (Tester + fallback), và dừng ở WorkBuddy GLM — đường OpenCode Zen Free đã bị tắt vì
hạn mức theo IP dùng chung (xem [`zen-free.md`](zen-free.md)). Khối DeepSeek chỉ còn một
rung: `workbuddy-ai/deepseek-v4.1-flash-sg` (bản thường đã bị provider bỏ; bản SG là
region khác, quota riêng). Trong khối GLM: `autoclaw/zaicoding_glm-5.3` đứng đầu vì đó
là model Tester, rồi GLM flash của AutoClaw, rồi WorkBuddy. `routing=order` nghĩa là:
model đầu trả lời; chỉ khi nó không trả lời được mới sang model sau. Hết danh sách quay
lại Leader — khép vòng `Leader → Coder → Tester → Leader`.

**`stays`.**

- `session`: hội thoại bám một tài khoản suốt phiên → prompt cache còn giá trị, rẻ và nhanh.
  Phù hợp chat.
- `turn`: mỗi lượt có thể đổi model (theo rule) → mỗi bước code dùng đúng model mạnh nhất
  cho việc đó. Phù hợp code.

**`levels`.** Agent được chọn `low`, `high`, `max`; model nào không có mức đó thì magpie
gửi mức gần nhất. Không đặt `medium` vì các model trong ladder không đồng đều.

**`effort=auto` + `classifier`.** Mỗi lượt, model nhỏ
`opencode-zen/jev-1.13-free` đọc yêu cầu và chọn mức reasoning
(low/high/max) thay vì agent luôn dùng một mức. Rẻ hơn cho câu hỏi ngắn, vẫn sâu cho việc
khó. Classifier chỉ là model *phụ*: nó không nằm trong ladder, không hiện ra cho agent chọn.

**Rule.** Rule đầu tiên khớp sẽ đưa model của nó lên đầu lượt đó; các model còn lại
vẫn ở sau làm fallback.

- `images` → `workbuddy-ai/hy4free`: đây là model đọc ảnh trong ladder hiện tại.
- `compact` → `workbuddy-ai/hy4free` rồi `workbuddy-ai/glm-5.3-flash`: nén hội thoại chỉ cần model free 1M; hy4free lỗi hoặc bị limit thì GLM flash nhận.
- `intent=…` → 4 kiểu việc code, chia theo bước: lên plan → viết code → test → review.
  Riêng bước test/review dùng GLM-5.3 vì nó kỹ hơn ở việc đọc lỗi.

## Sửa group

```sh
magpie group main                      # xem định nghĩa hiện tại
magpie group code
magpie groups                          # danh sách + rule + agent nào dùng

magpie group set main models+=deepseek/deepseek-v4-pro   # thêm vào cuối
magpie group set main models-=autoclaw/zai_glm-5.3-flash # bỏ
magpie group set code stays=session                      # đổi cách giữ hội thoại
magpie group set main levels=low,medium,high,max
magpie group set main effort=agent                       # tắt classifier, để agent tự chọn
magpie group set main classifier=opencode-zen/jev-1.13-free

magpie group rule main                    # rule đang có, đánh số
magpie group rule add main use=… tokens=200k
magpie group rule rm main 2
magpie group rule mv main 3 1
magpie group rm code                      # xoá group
```

Lưu ý: `magpie group add <tên đã dùng>` **thay** group đó. `scripts/setup-groups.sh`
chỉ thay khi có `--force`; `finish.sh` gọi với `--force` vì nó là nguồn định nghĩa.

## Kiểm tra

```sh
magpie group main | head -20
magpie models opencode | grep group
magpie claude group/main      # nếu có Claude Code
magpie opencode group/main
```

Agent đọc model lúc khởi động — mở phiên mới để thấy thay đổi.
