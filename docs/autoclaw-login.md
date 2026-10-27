# Đăng nhập AutoClaw (Zhipu) — phần quan trọng nhất

AutoClaw **không dùng API key**. Nó là OAuth chạy trong trình duyệt, do plugin
[`@magpie-community/opencode-autoclaw-auth`](https://github.com/magpie-community/plugins/tree/main/packages/autoclaw)
lo toàn bộ: mở một server tạm trên máy bạn, dẫn qua trang uỷ quyền, bắt callback,
rồi tự đóng. Bạn không phải copy code, không phải dán token.

Plugin đăng ký **hai** provider, dùng cho hai loại tài khoản:

| id | Vùng | Đăng nhập | Host upstream |
|---|---|---|---|
| `autoclaw` | quốc tế | Google hoặc z.ai (web OAuth) | `autoglm-api.autoglm.ai` |
| `autoclaw-cn` | Trung Quốc | số điện thoại +86 (SMS) | `autoglm-api.zhipuai.cn` |

Model thực dùng được (4, theo routeModelId của upstream):

```
autoclaw/zai_auto              (tự định tuyến, có reasoning low/high/max)
autoclaw/zai_auto-fast
autoclaw/zai_glm-5.3-flash
autoclaw/zaicoding_glm-5.3     (GLM-5.3 coding plan — model chính trong group)
```

## 1. Cài plugin

```sh
magpie plugin add @magpie-community/opencode-autoclaw-auth
```

Lần đầu magpie tải bun (~180 MB) vào `~/.cache/magpie/bun/`. Không cần root.

## 2. Đăng nhập (quốc tế — `autoclaw`)

```sh
magpie plugin login autoclaw
```

Nó hỏi **登录方式 / login method**:

```
1. Google 账号      → chọn 1
2. z.ai 账号        → chọn 2
```

Sau khi chọn, plugin:

1. Chọn một cổng trống trong **18432, 19654, 19723, 53699** — đây là whitelist của
   OAuth client chính thức, không đổi được.
2. Bật server tạm nghe `127.0.0.1:<cổng>` và in ra URL dạng
   `http://127.0.0.1:18432/`.
3. Trang hướng dẫn đó: bạn qua **slider Aliyun** → sang trang uỷ quyền Google/z.ai →
   đồng ý → trình duyệt được redirect về `http://localhost:<cổng>/auth/callback-…`,
   plugin bắt `code` (phải khớp `state` đã phát), đổi lấy token, lưu vào
   `~/.config/magpie/plugin-auth.json` (quyền 600), rồi đóng server.
4. Không hoàn tất trong 10 phút thì phiên tự huỷ và nhả cổng. Bắt đầu lại bằng
   cách chạy lại lệnh.

> **Điều kiện bắt buộc:** trình duyệt phải ở **cùng máy** với magpie, vì callback
> trỏ tới `127.0.0.1`/`localhost`. Trên Cloud Shell (trình duyệt ở máy bạn) phải
> chuyển tiếp cổng — xem mục 3.

## 3. Cloud Shell / máy headless — ba cách

### Cách A — chuyển tiếp cổng (khuyến nghị, không cần máy khác cài gì)

Mở một phiên SSH từ **máy bạn** tới Cloud Shell, forward cả 4 cổng:

```sh
gcloud cloud-shell ssh --authorize-session \
  --ssh-flag="-L 18432:127.0.0.1:18432" \
  --ssh-flag="-L 19654:127.0.0.1:19654" \
  --ssh-flag="-L 19723:127.0.0.1:19723" \
  --ssh-flag="-L 53699:127.0.0.1:53699"
```

Nếu có SSH trực tiếp tới máy chạy magpie thì tương đương:

```sh
ssh -L 18432:127.0.0.1:18432 -L 19654:127.0.0.1:19654 \
    -L 19723:127.0.0.1:19723 -L 53699:127.0.0.1:53699 <user@host>
```

Trong **phiên SSH đó** chạy:

```sh
magpie plugin login autoclaw
```

Rồi mở URL `http://127.0.0.1:<cổng>` **trên máy bạn** (cổng đã được forward về Cloud Shell).
Chọn Google/z.ai, làm theo trang. Xong là token nằm trên Cloud Shell.

Vì sao forward cả 4 cổng: plugin lấy cổng trống đầu tiên; forward sẵn cả 4 thì không
phải sửa lệnh SSH khi cổng 18432 bận.

### Cách B — đăng nhập trên máy có desktop rồi chuyển token

Trên máy có trình duyệt (macOS/Windows/Linux desktop), cài magpie và:

```sh
magpie plugin add @magpie-community/opencode-autoclaw-auth
magpie plugin login autoclaw            # trình duyệt tự mở, làm bình thường
magpie backup --no-library ~/magpie.mgb # đặt passphrase khi được hỏi
```

Copy `~/magpie.mgb` sang Cloud Shell rồi:

```sh
magpie restore --no-agents ~/magpie.mgb  # nhập lại passphrase
```

`--no-agents` để không ghi đè cấu hình agent trên máy đích. File backup chứa cả
provider/account đã đăng nhập, nên cách này chuyển được AutoClaw, WorkBuddy, Qoder
cùng lúc.

### Cách C — đồng bộ nhiều máy

Nếu bạn dùng nhiều máy thường xuyên, bật đồng bộ mã hoá của magpie:

```sh
magpie github on github://<owner>/<repo>   # file mã hoá trong repo GitHub
# hoặc
magpie webdav on <address>                 # Nextcloud, Nutstore…
# hoặc
magpie s3 on s3://<bucket>[/<prefix>]
```

Máy nào cũng có provider, account, group, model của agent như nhau. Lần đầu vẫn
phải đăng nhập ở một máy có trình duyệt.

## 4. Đăng nhập bản Trung Quốc (`autoclaw-cn`)

```sh
magpie plugin login autoclaw-cn
```

Nhập số điện thoại +86, nhận SMS. Bản này chỉ nhận tài khoản số điện thoại; tài khoản
Google/z.ai chỉ dùng được với `autoclaw` (sai host sẽ 401/403).

## 5. Kiểm tra

```sh
magpie accounts | grep -i autoclaw     # tên tài khoản + credit + điểm danh
magpie quota                           # số dư từng ví
magpie provider test autoclaw zai_auto # gửi 1 request thật
magpie models | grep autoclaw          # 4 model
```

Trạng thái tốt trông như sau:

```
● autoclaw Nguyen Van Duc   每日签到 今日已签 ✓ +400  10396 积分 left
○ autoclaw Đức Nguyễn Văn  …
```

`●` là tài khoản đang dùng, `○` là tài khoản dự phòng khi hết credit.

## 6. Nhiều tài khoản

Chạy lại `magpie plugin login autoclaw` để thêm tài khoản thứ hai, ba… magpie tự
failover khi hết credit:

```sh
magpie accounts                                  # xem tất cả
magpie accounts switch autoclaw <email>          # đổi tài khoản đang dùng
magpie provider account-cap autoclaw <email> 70  # chỉ dùng 70% mỗi cửa sổ
magpie provider rpm autoclaw 20                  # giới hạn 20 request/phút
```

## 7. Điểm danh hằng ngày (daily check-in)

AutoClaw cho credit miễn phí mỗi ngày khi điểm danh:

- **Cách chuẩn (magpie ≥ 0.1.1083):** mở web UI → **Settings → Usage → Plugins** →
  bật **Daily check-in** cho `autoclaw`. Mặc định **tắt**. Mỗi ngày mỗi tài khoản
  được điểm danh một lần (giờ Bắc Kinh), cũng có nút **Check in now**.
- **Cách cũ (tự điểm danh khi kiểm tra quota):**

  ```sh
  magpie plugin options @magpie-community/opencode-autoclaw-auth '{"signin":true,"signinOnUsage":true}'
  # hoặc file ~/.config/magpie/autoclaw.json (đọc lại ngay, không cần restart)
  ```

`magpie quota` luôn hiện dòng điểm danh: `今日已签 ✓` (hôm nay đã điểm danh) hay
`今日未签 +N`.

## 8. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| URL `127.0.0.1:<cổng>` không mở được | trình duyệt không ở cùng máy | Cách A (forward cổng) |
| `本地端口 18432/19654/19723/53699 均被占用` | có AutoClaw desktop/TokenServer đang giữ cổng | tắt app đó, hoặc dùng máy khác |
| Trang báo phiên hết hạn | quá 10 phút | chạy lại `magpie plugin login autoclaw` (đừng dùng lại URL cũ) |
| `406 Not Acceptable` | request sai shape | plugin đã tự vá system prompt/`max_tokens`; cập nhật plugin: `magpie plugin update` |
| Tài khoản bị "kicked" | cùng tài khoản đăng nhập ở AutoClaw desktop (refresh token dùng chung, hai bên luân phiên) | chỉ đăng nhập một nơi |
| `400 非法模型` | model đã bị upstream gỡ | `magpie provider models autoclaw`, chọn model còn trong danh sách |
| 403 "hết quota" nhưng vẫn đăng nhập | hết credit, không phải mất login | nạp/điểm danh, hoặc để group chuyển model kế tiếp |
| Tài khoản bị ban (410004) | vi phạm của upstream | không tự khắc phục được; dùng tài khoản khác |

## 9. Ghi chú

- Đây là plugin **cộng đồng, không chính thức**, làm bằng cách phân tích ngược client
  chính thức. Upstream đổi giao thức là có thể hỏng; dùng thì tự chịu rủi ro khoá tài khoản.
- Credit là **điểm**, không phải cửa sổ quota theo thời gian — nên `magpie quota`
  hiện số dư chứ không hiện "% đã dùng".
- Token lưu ở `~/.config/magpie/plugin-auth.json` (600). Đừng commit, đừng copy vào repo.
- Đừng đăng nhập cùng lúc trên AutoClaw desktop và magpie với cùng tài khoản.
