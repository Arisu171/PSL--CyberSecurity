<!doctype html>
<html lang="en">
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
		<title>SQL Injection Pentest - Example 1 (FIXED / REMEDIATED)</title>
	</head>
	<body style="margin-top: 50px">
		<div class="container">
			<div class="row">
				<div class="span6">
					<?php
						$host = "127.0.0.1";
						$username = "root";
						$password = "123456";
						$db_name = "webvul";
						
						try {
							// 1. Sử dụng PDO thay cho kết nối mysql_* truyền thống
							$pdo = new PDO("mysql:host=$host;dbname=$db_name;charset=utf8", $username, $password, [
								PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
								PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
								PDO::ATTR_EMULATE_PREPARES => false
							]);

							$cat = isset($_GET['cat']) ? $_GET['cat'] : '';

							// 2. Sử dụng Prepared Statement với tham số định danh :cat
							$stmt = $pdo->prepare("SELECT vendor, model, price FROM tbl_product WHERE category = :cat");
							
							// 3. Ràng buộc tham số chặt chẽ (Parameter Binding)
							$stmt->bindParam(':cat', $cat, PDO::PARAM_STR);
							$stmt->execute();
							
							$rows = $stmt->fetchAll();
							if (!empty($rows)) {
								echo "<h4>-- Product Information (Secured with Prepared Statements) --</h4>";
								foreach ($rows as $row) {
									echo "<p>Vendor : " . htmlspecialchars($row['vendor']) . "</p>";
									echo "<p>Model : " . htmlspecialchars($row['model']) . "</p>";
									echo "<p>Price : " . htmlspecialchars($row['price']) . "$</p>";
									echo "--------------------------------------------";
								}
							} else {
								echo "<p>No products found for category: " . htmlspecialchars($cat) . "</p>";
							}
						} catch (PDOException $e) {
							// 4. Không để lộ chi tiết lỗi SQL ra giao diện người dùng
							echo "<p>Lỗi hệ thống! Vui lòng liên hệ quản trị viên.</p>";
							// error_log($e->getMessage()); // Ghi nhật ký lỗi an toàn vào file log
						}
					?>
				</div>
			</div>
		</div>
	</body>
</html>
