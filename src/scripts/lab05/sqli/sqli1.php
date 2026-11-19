<!doctype html>
<html lang="en">
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
		<title>SQL Injection Pentest - Example 1</title>
	</head>
	<body style="margin-top: 50px">
		<div class="container">
			<div class="row">
				<div class="span6">
					<?php
						require_once __DIR__ . '/mysql_compat.php';
						$host="localhost";
						$username="root";
						$password="123456";
						$db_name="webvul";
						
						$con=mySQL_connect("$host", "$username", "$password") or die("cannot connect"); 
						mySQL_select_db("$db_name")or die("cannot select DB");
											
						$cat = $_GET['cat'];
						$SQL = "select * from tbl_product where category = '$cat'";
						$result = mySQL_query($SQL);
						
						if($result){
								echo "<h4>"."-- Product Information -- "."</h4>";
								while ($row=mySQL_fetch_row($result)){
									echo "<p>"."Vendor : ".$row[1]."</p>";
									echo "<p>"."Model : ".$row[2]."</p>";
									echo "<p>"."Price :".$row[3]."$</p>";

									echo "--------------------------------------------";
								}
						}else
								echo mysql_error();
					?>
				</div>
			</div>
		</div>
	</body>
</html>
