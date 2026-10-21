# Script PowerShell tien ich dieu khien Lab 02 tu xa qua SSH

$VM_USER = "orias"
$VM_IP = "192.168.117.10"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "     DIEU KHIEN LAB 02 QUA SSH (WINDOWS)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. Chay setup cai dat Docker va khoi dong Lab"
Write-Host "2. Truy cap vao may Attacker (Container)"
Write-Host "3. Truy cap vao may User (Container)"
Write-Host "4. Truy cap vao may Server (Container)"
Write-Host "5. Kiem tra danh sach container tren VM"
Write-Host "6. Dang nhap SSH truc tiep vao may ao Ubuntu"
$choice = Read-Host "Chon thao tac [1-6]"

switch ($choice) {
    "1" { ssh -t "$VM_USER@$VM_IP" "bash ~/it4263lab/lab02/setup_vm.sh" }
    "2" { ssh -t "$VM_USER@$VM_IP" "sudo docker exec -it attacker-10.11.1.51 /bin/bash" }
    "3" { ssh -t "$VM_USER@$VM_IP" "sudo docker exec -it user-10.11.1.10 /bin/bash" }
    "4" { ssh -t "$VM_USER@$VM_IP" "sudo docker exec -it server-10.11.1.20 /bin/bash" }
    "5" { ssh "$VM_USER@$VM_IP" "sudo docker ps" }
    "6" { ssh "$VM_USER@$VM_IP" }
    Default { Write-Host "Lua chon khong hop le!" -ForegroundColor Red }
}

