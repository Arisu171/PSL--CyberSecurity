<!doctype html>
<html lang="en">
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
		<title>SQL Injection Pentest - Example 2</title>
	</head>
	<body style="margin-top: 50px">
		<?php
			require_once __DIR__ . '/mysql_compat.php';
			$host="localhost";
			$username="root";
			$password="123456";
			$db_name="webvul";
					
			$con=mySQL_connect("$host", "$username", "$password") or die("cannot connect"); 
			mySQL_select_db("$db_name")or die("cannot select DB");
											
			$cat = $_POST['cat'];
			$vendor = $_POST['vendor'];
			$model = $_POST['model'];
			$price = $_POST['price'];
			$SQL = "INSERT INTO tbl_product(vendor, model, price, category) VALUES('" . $vendor . "', '" . $model . "', '" . $price ."', '" . $cat ."')";
			
			$insert = mysql_query($SQL);
			
			if(!$insert){
				//echo ("Error! Cannot add product");
				echo mysql_error();
			}
		?>
		
		<center><h3>Product list:</h3>

		<table>

			<tr height="30" bgcolor="#066923" align="center">
				<td width="150"><b>Category</b></td>
				<td width="150"><b>Vendor</b></td>
				<td width="200"><b>Model</b></td>
				<td width="100"><b>Price</b></td>
			</tr>
			<?php
				$SQL= "SELECT category, vendor, model, price FROM tbl_product ORDER BY category, vendor, model";
				$result = mysql_query($SQL);
				if($result){
					if(mysql_num_rows($result)>0){
						while ($row=mysql_fetch_row($result)){
							echo '<tr height="40">';
							echo '<td>'.$row[0].'</td>';
							echo '<td>'.$row[1].'</td>';
							echo '<td>'.$row[2].'</td>';
							echo '<td>'.$row[3].'</td>';
							echo '</tr>';
						}
					}
				}else
					echo ("Oops! Something went wrong");
				
			?>
		</table></center>
					
	</body>
</html>
