# Thành viên 3 — Tabu Search và thực nghiệm

## Phương pháp

Mỗi trạng thái tìm kiếm gồm nghiệm hiện tại, nghiệm tốt nhất toàn cục, hai hàng
đợi tabu FIFO và số vòng không cải thiện. Ở mỗi vòng, chương trình sinh các
láng giềng bằng module phần 2, loại các phép tabu và so sánh makespan. Nếu một
láng giềng cải thiện nghiệm tốt nhất toàn cục, chương trình nhận ngay. Nếu
không, TSR chọn láng giềng redistribute tốt nhất với xác suất `β = 0,3`, còn
lại chọn reroute/reverse tốt nhất; khi một nhóm rỗng thì chọn nhóm còn lại.
TSO chỉ xét reroute/reverse. Đây là quy tắc Algorithm 9 trong luận án 2025.

Kích thước tabu list và số láng giềng theo Bảng 5.2: TSO có `TL_add = ⌊n/8⌋`,
`n_reroute = ⌊n/3⌋`, `n_reverse = ⌊n/9⌋`; TSR có `TL_add = ⌊n/8⌋`,
`TL_redis = ⌊n/15⌋`, `n_reroute = ⌊n/5⌋`, `n_reverse = ⌊n/15⌋`,
`n_redis = ⌊n/15⌋`. Cả hai dừng sau 5.000 vòng, quay về nghiệm tốt nhất sau
300 vòng không cải thiện và tạo nghiệm đầu mới sau 600 vòng. Nghiệm tốt nhất
toàn cục được giữ qua mọi lần restart. Nghiệm đầu và mỗi nghiệm restart là nghiệm
tốt nhất trong 50 lần chạy S-greedy Algorithm 5–6 của luận án, với khoảng chèn
`(1,2)`. Trong một lượt, Algorithm 6 duyệt các cặp (task, robot) theo thời điểm
đến tăng dần, gán đủ robot cho tối đa `kinsert` task và đồng bộ thời điểm kết
thúc của các robot được gán. Hàm trả về `Solution` phần 1, sau đó chuyển sang
`FlowSolution` phần 2 để Tabu Search sử dụng.

## Thiết kế thực nghiệm

- `n ∈ {15,30,50}`, `m ∈ {5,10}`, seed instance `1,2`: 12 cặp TSO/TSR.
- Mỗi cặp dùng cùng tọa độ, số robot yêu cầu và nghiệm đầu. Nhu cầu robot lấy
  đều từ `1..5`; thời gian xử lý là khoảng cách Euclid pickup đến delivery.
- Mỗi nghiệm đầu và restart lấy tốt nhất từ 50 lần S-greedy `(1,2)` với seed cố định.
- Mỗi phiên bản chạy 5.000 vòng. Thời gian đo riêng vòng Tabu Search, gồm các
  lần khởi tạo lại nhưng không gồm 50 lần S-greedy tạo nghiệm đầu dùng chung.
  Bước làm nóng Julia giảm sai lệch do biên dịch lần đầu; máy và phiên bản Julia
  cụ thể ảnh hưởng số giây.
- `runs.csv` ghi từng lượt, `summary.csv` nhóm theo `(n,m)`, `convergence.csv`
  lấy giá trị tốt nhất đang có mỗi 100 vòng và chuẩn hóa theo makespan đầu.

## Kết quả

| n | m | Số cặp TSR tốt hơn / 2 | Makespan TB TSO | Makespan TB TSR | Cải thiện TB mỗi cặp |
|---:|---:|---:|---:|---:|---:|
| 15 | 5 | 0 | 943,96 | 958,01 | −1,51% |
| 15 | 10 | 2 | 537,10 | 517,19 | +3,60% |
| 30 | 5 | 0 | 1661,24 | 1661,24 | 0,00% |
| 30 | 10 | 0 | 835,88 | 861,39 | −3,49% |
| 50 | 5 | 0 | 2595,15 | 2599,98 | −0,19% |
| 50 | 10 | 0 | 1341,00 | 1341,00 | 0,00% |

Tổng cộng TSR tốt hơn ở **2/12 cặp (16,7%)**, bằng ở 4 cặp và kém ở 6 cặp. Trung bình
12 mức cải thiện theo cặp là **−0,26%**. TSR chậm hơn TSO trong cả sáu nhóm
nhỏ này; xem số giây chính xác trong `results/member3/summary.csv`.
Các đồ thị trong `plots/member3/` cho thấy đường hội tụ tính từ incumbent,
tương tự cách chuẩn hóa của Hình 12: 100% là nghiệm đầu, thấp hơn là tốt hơn.

## Phạm vi và bước cải thiện

Kết quả trên **không xác nhận** con số khoảng 1,66% và 8/10 trong Bảng 5 của
bản special issue. Bảng đó dùng các instance PDP Li & Lim đã biến đổi với
100–500 task, 10 instance mỗi kích thước và 10 robot. Thực nghiệm ở đây dùng
instance ngẫu nhiên 15–50 task và chỉ hai seed mỗi nhóm. Algorithm 5–6 và
best-of-50 đã được cài, nhưng không có dữ liệu gốc và cách chọn biến thể
S-greedy theo từng kích thước ở đây dùng cố định khoảng `(1,2)`. Các chi tiết
chọn láng giềng của phần 2 cũng có thể khác hiện thực tác giả. Vì vậy không thể dùng
chênh lệch ở đây để kiểm định độ trung thực của kết quả gốc.

Ưu tiên tiếp theo là nhập các instance Li & Lim gốc và quy trình biến đổi, rồi chạy 10 instance mỗi kích thước lớn
với cùng phần cứng và cấu hình. Sau đó nên lặp nhiều seed cho heuristic để
ước lượng độ biến thiên và kiểm tra lại điều kiện chọn láng giềng của phần 2.
