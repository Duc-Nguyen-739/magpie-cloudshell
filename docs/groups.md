# Routing group — hai group đang dùng

Group là nhiều model mà agent chọn như **một**. Agent trỏ vào `group/main`; gateway
quyết định model nào trả lời từng lượt, và tự chuyển model kế tiếp khi model hiện tại
hỏng, hết quota hoặc bị chặn.

## Định nghĩa

### `group/main` — chat thường ngày

```sh
magpie group add "Main" \
  models=workbuddy-ai/deepseek-v4.1-flash,workbuddy-ai/glm-5.3,workbuddy-ai/deepseek-v4.1-flash-sg,workbuddy-ai/glm-5.3-flash,autoclaw/zaicoding_glm-5.3,autoclaw/zai_glm-5.3-flash,opencode-zen/deepseek-v4.1-flash-free,opencode-zen/glm-5.3-flash-free \
  routing=order stays=session

magpie group set main levels=low,high,max
magpie group set main classifier=opencode-zen/jev-1.13-free
magpie group set main effort=auto

magpie group rule add main use=workbuddy-ai/deepseek-v4.1-flash images
magpie group rule add main use=workbuddy-ai/glm-5.3-flash compact
```

### `group/code` — công việc code

Cùng ladder, nhưng `stays=turn` và 4 rule theo ý định:

```sh
magpie group add "Code" models=<như trên> routing=order stays=turn
magpie group set code levels=low,high,max
magpie group set code classifier=opencode-zen/jev-1.13-free
magpie group set code effort=auto

magpie group rule add code use=workbuddy-ai/deepseek-v4.1-flash \
  intent="asking for a detailed plan before any code is written (lên plan, lập kế hoạch chi tiết)"
magpie group rule add code use=workbuddy-ai/deepseek-v4.1-flash \
  intent="writing, implementing or fixing code (viết code, code theo plan, implement, sửa code)"
magpie group rule add code use=workbuddy-ai/glm-5.3 \
  intent="running tests or checking the code just written, before it is finished (kiểm tra, test code vừa viết)"
magpie group rule add code use=workbuddy-ai/deepseek-v4.1-flash \
  intent="final overall review of the finished code and releasing or publishing it (kiểm tra tổng thể lần cuối, duyệt, phát hành, release, ship)"
magpie group rule add code use=workbuddy-ai/deepseek-v4.1-flash images
```

## Vì sao như vậy

**Thứ tự model.** Đầu ladder là WorkBuddy AI DeepSeek V4.1 Flash — nhanh, rẻ, đủ tốt cho
phần lớn lượt. Sau đó là GLM-5.3 (mạnh hơn cho code/review), rồi bản SG của DeepSeek
(region khác, quota riêng), GLM-5.3 Flash, rồi mới sang AutoClaw (credit điểm, dùng
tiết kiệm), cuối cùng là hai model free của OpenCode Zen (không giới hạn nhưng chậm hơn).
`routing=order` nghĩa là: model đầu trả lời; chỉ khi nó không trả lời được mới sang model sau.

**`stays`.**

- `session`: hội thoại bám một tài khoản suốt phiên → prompt cache còn giá trị, rẻ và nhanh.
  Phù hợp chat.
- `turn`: mỗi lượt có thể đổi model (theo rule) → mỗi bước code dùng đúng model mạnh nhất
  cho việc đó. Phù hợp code.

**`levels`.** Agent được chọn `low`, `high`, `max`; model nào không có mức đó thì magpie
gửi mức gần nhất. Không đặt `medium` vì các model trong ladder không đồng đều.

**`effort=auto` + `classifier`.** Mỗi lượt, model nhỏ `opencode-zen/jev-1.13-free` đọc
yêu cầu và chọn mức reasoning (low/high/max) thay vì agent luôn dùng một mức. Rẻ hơn
cho câu hỏi ngắn, vẫn sâu cho việc khó. Classifier chỉ là model *phụ*: nó không nằm
trong ladder, không hiện ra cho agent chọn.

**Rule.** Rule đầu tiên khớp sẽ đưa model của nó lên đầu lượt đó; các model còn lại
vẫn ở sau làm fallback.

- `images` → model mạnh nhất (DeepSeek V4.1 Flash): ảnh cần model đọc được ảnh tốt.
- `compact` → GLM-5.3 Flash: nén hội thoại chỉ cần model rẻ, nhanh.
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
