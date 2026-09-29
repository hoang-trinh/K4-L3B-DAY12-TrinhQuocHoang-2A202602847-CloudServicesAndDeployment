# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: điền câu trả lời bên dưới mỗi câu hỏi.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Trịnh Quốc Hoàng  Mã học viên: 2A202602847

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Tình huống: Khi deploy service lên môi trường cloud (Render, Railway hoặc Production), dev quên cấu hình biến môi trường `AGENT_API_KEY` trong dashboard. Nếu để mặc định `"changeme"`, ứng dụng vẫn khởi động bình thường; kẻ tấn công hoặc bot quét Internet có thể dùng ngay khóa mặc định này để gọi API `/ask` miễn phí, làm cạn kiệt ngân sách LLM và quota dịch vụ. Nhờ cơ chế Fail Fast, ứng dụng ném lỗi `ValidationError` và crash ngay lúc khởi động, buộc người vận hành phải vào dashboard điền khóa thật thì service mới có thể chạy.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log JSON thu được:
`{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T04:57:58.824125+00:00", "user_id": "sv01", "tokens_in": 3, "tokens_out": 41, "cost_usd": 0.00002505}`

Hai việc làm được với log JSON mà print chuỗi văn bản thuần túy không làm được:
1. **Lọc và tổng hợp tự động theo trường (Field-based Filtering & Aggregation):** Các hệ thống thu thập log tập trung (như Datadog, CloudWatch, Loki) có thể parse trực tiếp JSON để tính toán, ví dụ: thống kê tổng chi phí `cost_usd` theo từng `user_id` trong ngày hoặc vẽ biểu đồ độ biến thiên của `tokens_out`.
2. **Thiết lập cảnh báo tự động theo ngưỡng (Automated Alerting):** Có thể cấu hình cảnh báo tự động (alert rule): nếu phát hiện log có `cost_usd > 0.01` hoặc `level == "error"` thì hệ thống tự động bắn thông báo khẩn qua Slack/PagerDuty cho đội trực vận hành.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1.19 GB |
| Multi-stage | 184 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch (~1.0 GB) bao gồm toàn bộ công cụ biên dịch mã nguồn (`gcc`, `g++`, `make`, `build-essential`), file header C/C++ của hệ điều hành, các gói manpages/tài liệu và cache của `pip` nằm trong image `python:3.11` đầy đủ. Ở bản multi-stage, các công cụ nặng này chỉ phục vụ cài đặt ở stage `builder` rồi bị loại bỏ hoàn toàn; stage `runtime` chỉ dùng base gọn nhẹ `python:3.11-slim` và copy thư viện đã cài đặt sang, giúp giảm dung lượng xuống còn 184 MB.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

- Với Dockerfile hiện tại: Các layer từ đầu cho đến `COPY requirements.txt .` và `RUN pip install ...` đều được tái sử dụng hoàn toàn từ cache (`CACHED`). Chỉ có layer `COPY . .` (và lệnh đổi quyền `chown` phía sau nó) là phải chạy lại, quá trình build lại chỉ mất khoảng 1-2 giây.
- Nếu đặt `COPY . .` lên trước `RUN pip install`: Mỗi lần sửa một ký tự trong code, toàn bộ context thay đổi làm Docker vô hiệu hóa cache từ layer `COPY . .` trở đi. Khi đó Docker buộc phải tải và cài lại toàn bộ danh sách thư viện trong `requirements.txt` từ đầu, làm tăng thời gian build lên vài phút và lãng phí băng thông mạng.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

- Chuỗi sự kiện: Khi container chạy mặc định bằng root (UID 0), nếu app Python có lỗ hổng RCE (Remote Code Execution) như qua deserialization, kẻ tấn công sẽ chiếm được quyền shell root bên trong container. Từ đây, nếu hệ thống có lỗ hổng thoát container (container breakout - ví dụ lỗ hổng Linux kernel, Docker socket `/var/run/docker.sock` bị mount, hoặc cấu hình namespace chưa cô lập), quyền root trong container sẽ ánh xạ thành quyền root (UID 0) trên máy host, cho phép kẻ tấn công kiểm soát toàn bộ máy chủ và dữ liệu.
- Lệnh `USER appuser` cắt đứt chuỗi tấn công ngay từ đầu: Khi app bị khai thác, kẻ tấn công chỉ có quyền của user thường `appuser` (UID 10001). User này không có quyền sửa đổi file nhạy cảm trong hệ thống, không có quyền sudo, và không thể lợi dụng đặc quyền quản trị để leo thang chiếm quyền máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Người dùng có thể gửi tối đa **20 request** trong 2 giây liên tiếp.
Giải thích: Ở giây `10:00:59` (giây cuối của phút trước), người dùng gửi 10 request (vừa vặn đạt hạn mức của phút 10:00). Ngay sau đó, ở giây `10:01:00`, bộ đếm phút chẵn bị reset về 0. Lúc `10:01:01` (giây đầu của phút mới), người dùng gửi thêm 10 request nữa. Tổng cộng chỉ trong 2 giây (từ `10:00:59` đến `10:01:01`), server phải hứng chịu 20 request (gấp đôi hạn mức tối đa), có thể gây nghẽn hoặc quá tải hệ thống.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

- Khác nhau: Rate limit quản lý **tần suất / số lượng request** trong một đơn vị thời gian ngắn (chống nghẽn hạ tầng và DoS). Cost guard quản lý **ngân sách tiền tệ thực tế tích lũy** theo tháng (chống cạn kiệt ngân sách tài chính).
- Rate limit cho qua nhưng Cost guard chặn: User chỉ gửi 1 request trong phút (hoàn toàn hợp lệ với rate limit 10 req/phút), nhưng tài khoản của user đó đã tiêu hết $9.99 trong ngân sách tháng $10.0. Câu hỏi mới cần xử lý tốn thêm $0.05. Rate limit cho qua nhưng Cost guard chặn lại với mã lỗi 402 Payment Required vì tổng chi phí sẽ vượt quá $10.0.
- Cost guard cho qua nhưng Rate limit chặn: Đầu tháng ngân sách còn nguyên $10.0 (chưa tiêu đồng nào). User dùng tool tự động gửi 15 request chỉ trong 3 giây. Dù tổng chi phí của 15 câu này rất nhỏ ($0.001 < $10.0, Cost guard đủ tiền chi trả), nhưng Rate limit sẽ chặn từ request thứ 11 với mã lỗi 429 Too Many Requests để bảo vệ tài nguyên chịu tải tức thời của server.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện xảy ra:
1. Redis mất kết nối hoặc khởi động lại trong 30 giây.
2. Endpoint gộp kiểm tra thấy Redis không phản hồi nên trả về mã lỗi 503.
3. Bộ điều phối (Orchestrator như Docker Swarm / Kubernetes / Cloud Agent) thấy Liveness probe thất bại nên kết luận rằng cả 3 process container `agent` đã bị hỏng/treo.
4. Orchestrator ra lệnh dừng và restart đồng loạt cả 3 container `agent`.
5. Trong khi cả 3 container đang trong quá trình khởi động lại, Redis phục hồi. Nhưng lúc này không còn container nào đang hoạt động để nhận traffic, toàn bộ người dùng gặp lỗi 502 Bad Gateway.
6. Khi 3 container khởi động lên cùng lúc, chúng tạo lượng tải kết nối dồn dập vào Redis, probe có thể tiếp tục timeout và kích hoạt chu kỳ restart tiếp theo (Restart storm / Cascading failure).

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Nếu lưu trong dict Python (trong RAM của từng process container): Khi có 3 instance, load balancer sẽ phân phối các request theo cơ chế round-robin lần lượt vào các instance khác nhau. Người dùng sẽ thấy `history_length` **thay đổi thất thường và nhảy lùi ngẫu nhiên** (ví dụ: lượt 1 vào container A có history=0, lượt 2 vào container B vẫn thấy history=0 vì B chưa từng gặp user, lượt 3 vào container A mới thấy history=2). AI sẽ có biểu hiện "mất trí nhớ", không nắm được ngữ cảnh hội thoại trước đó.
Khi dùng Redis, cả 3 container cùng đọc ghi một nơi, `history_length` tăng đều đặn `0 -> 2 -> 4 -> 6...` bất kể request rơi vào container nào.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- Thông báo lỗi: Container bị thoát ngay khi khởi động (`Exited (3)`), kiểm tra log thấy `NotImplementedError: TODO (CP4): cài đặt install` tại dòng `lifecycle.install()`.
- Cách tìm ra nguyên nhân: Chạy lệnh `docker compose logs agent` để xem trực tiếp stack trace của tiến trình Uvicorn bên trong container thay vì chỉ nhìn trạng thái thoát chung chung.
- Cách sửa: Hoàn thiện phương thức `install()` và `request_shutdown()` trong file `app/lifecycle.py` để đăng ký đúng signal handler cho `SIGTERM`/`SIGINT`, đồng thời chuyển tiếp tín hiệu lại cho handler mặc định của Uvicorn để server thực hiện graceful shutdown. Sau đó build lại image qua `docker compose up -d --build`.
