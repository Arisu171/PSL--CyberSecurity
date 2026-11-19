<!doctype html>
<html lang="en">
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
		<title>SQL Injection Pentest - Example 2 (FIXED / REMEDIATED)</title>
	</head>
	<body style="margin-top: 50px">
		<?php
			$host = "127.0.0.1";
			$username = "root";
			$password = "123456";
			$db_name = "webvul";
			
			try {
				$pdo = new PDO("mysql:host=$host;dbname=$db_name;charset=utf8", $username, $password, [
					PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
					PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
					PDO::ATTR_EMULATE_PREPARES => false
				]);

				if ($_SERVER['REQUEST_METHOD'] === 'POST') {
					$cat    = isset($_POST['cat']) ? trim($_POST['cat']) : '';
					$vendor = isset($_POST['vendor']) ? trim($_POST['vendor']) : '';
					$model  = isset($_POST['model']) ? trim($_POST['model']) : '';
					$price  = isset($_POST['price']) ? (float)$_POST['price'] : 0.0;

					// Sử dụng Prepared Statement ngăn chặn SQL Injection tại câu lệnh INSERT
					$sql = "INSERT INTO tbl_product (vendor, model, price, category) VALUES (:vendor, :model, :price, :category)";
					$stmt = $pdo->prepare($sql);
					$stmt->execute([
						':vendor'   => $vendor,
						':model'    => $model,
						':price'    => $price,
						':category' => $cat
					]);
					echo "<p style='color: green;'>[+] Product added successfully (Secured)!</p>";
				}
			} catch (PDOException $e) {
				echo "<p style='color: red;'>[-] Lỗi thêm sản phẩm! Dữ liệu đầu vào không hợp lệ.</p>";
			}
		?>
		
		<center><h3>Product list:</h3>
		<table border="1" cellpadding="5" cellspacing="0">
			<tr height="30" bgcolor="#066923" style="color: white;" align="center">
				<td width="150"><b>Category</b></td>
				<td width="150"><b>Vendor</b></td>
				<td width="200"><b>Model</b></td>
				<td width="100"><b>Price</b></td>
			</tr>
			<?php
				try {
					if (isset($pdo)) {
						$stmt = $pdo->query("SELECT category, vendor, model, price FROM tbl_product ORDER BY category, vendor, model");
						while ($row = $stmt->fetch()) {
							echo '<tr height="30" align="center">';
							echo '<td>' . htmlspecialchars($row['category']) . '</td>';
							echo '<td>' . htmlspecialchars($row['vendor']) . '</td>';
							echo '<td>' . htmlspecialchars($row['model']) . '</td>';
							echo '<td>' . htmlspecialchars($row['price']) . '$</td>';
							echo '</tr>';
						}
					}
				} catch (Exception $e) {
					echo "<tr><td colspan='4'>Không thể tải danh sách sản phẩm.</td></tr>";
				}
			?>
		</table>
		</center>
	</body>
</html>
