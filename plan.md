# KẾ HOẠCH BÀI TẬP NHÓM: BÀI TOÁN PDP-CR

## 1. Phân công đề xuất

### Thành viên 1 — Mô hình bài toán và dữ liệu
**Nhiệm vụ chính:**
- Đọc và trình bày bài toán PDP-CR.
- Xây dựng cấu trúc dữ liệu:
  - Tập robot ($M$).
  - Tập nhiệm vụ ($N$).
  - Điểm lấy hàng ($p_i$).
  - Điểm giao hàng ($d_i$).
  - Thời gian xử lý ($c_i$).
  - Số robot cần thiết ($r_i$).
- Tính thời gian di chuyển ($t_{ij}$).
- Cài đặt hàm đánh giá makespan.
- Xây dựng nghiệm ban đầu bằng phương pháp greedy.
- Kiểm tra tính khả thi của nghiệm:
  - Mỗi nhiệm vụ nhận đủ robot.
  - Robot bắt đầu từ depot.
  - Robot kết thúc tại depot.
  - Không vi phạm thứ tự và thời gian thực hiện.

> **Ghi chú bài báo:** Trong bài báo, mỗi nhiệm vụ được mô tả bởi vị trí pickup, vị trí delivery, thời gian xử lý và số robot yêu cầu; mục tiêu là tối thiểu hóa makespan, tức thời điểm robot cuối cùng quay về depot (tr. 2).

**Sản phẩm cần bàn giao:**
- `data.py`
- `solution.py`
- `evaluator.py`
- `initial_solution.py`

*Thành viên này cũng nên viết phần mô hình bài toán và cách biểu diễn dữ liệu trong báo cáo.*

---

### Thành viên 2 — Biểu diễn nghiệm và các neighborhood
**Nhiệm vụ chính:**
- Cài đặt nghiệm dưới dạng directed acyclic graph (DAG).
- Mỗi node biểu diễn một nhiệm vụ.
- Mỗi cung ($(i,j)$) lưu số flow ($f_{ij}$), trong đó một đơn vị flow tương ứng với một robot.
- Cài đặt ba neighborhood:
  1. Redistribute neighborhood
  2. Reroute neighborhood
  3. Reverse neighborhood
- Kiểm tra tính hợp lệ của đồ thị sau mỗi phép biến đổi.
- Viết các hàm:
  - Tính thứ tự topo.
  - Chọn vị trí cắt ($\zeta$).
  - Chia đồ thị thành $N^{\text{left}}$ và $N^{\text{right}}$.
  - Tính flow đi qua lát cắt.
  - Phân phối lại flow.
  - Tính makespan trước và sau phép biến đổi.

> **Ghi chú bài báo:** Đây là phần quan trọng nhất của bài báo. Redistribute neighborhood cắt đồ thị theo thứ tự topo, sau đó phân phối lại các flow giữa hai phía của lát cắt nhằm giảm makespan (tr. 5–9). Reroute neighborhood hoán đổi flow giữa hai cung, còn reverse neighborhood đảo chiều một cung và điều chỉnh các flow liên quan (tr. 10–12).

**Sản phẩm cần bàn giao:**
- `flow_graph.py`
- `neighborhoods.py`
- `redistribute.py`
- `reroute.py`
- `reverse.py`

*Thành viên này nên viết phần phương pháp đề xuất và các thuật toán neighborhood trong báo cáo.*

---

### Thành viên 3 — Tabu Search và thực nghiệm
**Nhiệm vụ chính:**
- Cài đặt Tabu Search.
- Quản lý:
  - Nghiệm hiện tại.
  - Nghiệm tốt nhất.
  - Tabu list.
  - Số vòng lặp.
  - Điều kiện dừng.
  - Cơ chế restart.
- Xây dựng hai phiên bản:
  - **TSO:** Tabu Search chỉ sử dụng hai neighborhood ban đầu.
  - **TSR:** Tabu Search bổ sung redistribute neighborhood.
- Cài đặt tham số thực nghiệm:
  - 5.000 iteration.
  - Restart sau 300 iteration không cải thiện.
  - Khởi tạo nghiệm mới sau 600 iteration không cải thiện.
- Chạy các kích thước dữ liệu khác nhau.
- Tính toán:
  - Makespan tốt nhất.
  - Makespan trung bình.
  - Thời gian chạy.
  - Tỷ lệ trường hợp TSR tốt hơn TSO.
  - Phần trăm cải thiện.
- Vẽ biểu đồ hội tụ tương tự Hình 12 của bài báo.

> **Ghi chú bài báo:** Bài báo so sánh TSO và TSR; kết quả cho thấy TSR cải thiện nghiệm trung bình khoảng 1,66% và tốt hơn trong khoảng 8/10 trường hợp, trong khi thời gian chạy tương đương ở nhiều kích thước dữ liệu (tr. 14–16).

**Sản phẩm cần bàn giao:**
- `tabu_search.py`
- `experiments.py`
- `statistics.py`
- `plot_results.py`

*Thành viên này nên viết phần thiết kế thực nghiệm, kết quả và đánh giá.*

---

## 2. Phần việc chung bắt buộc

Không nên để một người làm riêng phần tích hợp. Cả nhóm cần cùng phụ trách:
- Thống nhất định dạng dữ liệu đầu vào.
- Thống nhất cách biểu diễn nghiệm.
- Review code của nhau.
- Kiểm tra các nghiệm nhỏ bằng tay.
- So sánh kết quả với ví dụ trong bài báo.
- Viết phần giới thiệu, kết luận và hạn chế.
- Chuẩn bị slide và phần trình bày.

### Cấu trúc thư mục thống nhất:
```text
project/
├── data/
├── src/
│   ├── data.py
│   ├── solution.py
│   ├── flow_graph.py
│   ├── neighborhoods.py
│   ├── tabu_search.py
│   └── evaluator.py
├── experiments/
├── results/
├── plots/
├── report/
└── README.md
```

---

## 3. Tiến độ gợi ý trong 6 tuần

| Tuần | Công việc chính |
| :--- | :--- |
| **1** | Cả nhóm đọc bài báo, thống nhất mục tiêu và giao diện chương trình |
| **2** | Thành viên 1 xây dựng dữ liệu và evaluator; Thành viên 2 thiết kế flow graph |
| **3** | Thành viên 2 cài đặt các neighborhood; Thành viên 3 cài đặt khung Tabu Search |
| **4** | Tích hợp toàn bộ chương trình và kiểm thử trên dữ liệu nhỏ |
| **5** | Chạy TSO/TSR, thu thập makespan và thời gian chạy |
| **6** | Phân tích kết quả, hoàn thiện báo cáo và chuẩn bị thuyết trình |

---

## 4. Phiên bản tối thiểu nếu thời gian hạn chế

Nếu thời gian ngắn, nhóm nên ưu tiên:
1. Chỉ sử dụng dữ liệu ngẫu nhiên nhỏ, khoảng 10–50 nhiệm vụ.
2. Cài đặt flow graph và hàm tính makespan.
3. Cài đặt redistribute neighborhood trước.
4. Cài đặt Tabu Search cơ bản.
5. So sánh:
   - Greedy.
   - Tabu Search không có redistribute.
   - Tabu Search có redistribute.
6. Chạy mỗi trường hợp nhiều lần với seed cố định.
7. Báo cáo makespan trung bình, tốt nhất và thời gian chạy.

> **Lưu ý:** Không nhất thiết phải tái tạo toàn bộ dữ liệu 500 nhiệm vụ hoặc mô hình MILP nếu mục tiêu chính là minh họa ý tưởng thuật toán. Cần ghi rõ đây là phiên bản rút gọn phục vụ học tập, không phải tái lập hoàn toàn thí nghiệm gốc.

---

## 5. Phân chia phần viết báo cáo

- **Thành viên 1:** Giới thiệu, phát biểu bài toán, mô hình dữ liệu.
- **Thành viên 2:** Biểu diễn flow graph và ba neighborhood.
- **Thành viên 3:** Tabu Search, thiết kế thực nghiệm và kết quả.
- **Cả nhóm:** Thảo luận, hạn chế, kết luận và slide.