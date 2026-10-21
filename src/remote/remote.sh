#!/bin/bash
# Script tien ich dieu khien Lab tu xa qua SSH

VM_USER="orias"
VM_IP="192.168.117.10"

echo "=== DIEU KHIEN LAB 02 QUA SSH ==="
echo "1. Chay setup cai dat Docker va khoi dong Lab"
echo "2. Truy cap vao may Attacker (Container)"
echo "3. Truy cap vao may User (Container)"
echo "4. Truy cap vao may Server (Container)"
echo "5. Kiem tra trang thai docker tren VM"
echo "6. Dang nhap truc tiep vao may ao Ubuntu"
read -p "Chon tuy chon [1-6]: " choice

case $choice in
    1)
        ssh -t ${VM_USER}@${VM_IP} "bash ~/it4263lab/lab02/setup_vm.sh"
        ;;
    2)
        ssh -t ${VM_USER}@${VM_IP} "docker exec -it attacker-10.11.1.51 /bin/bash"
        ;;
    3)
        ssh -t ${VM_USER}@${VM_IP} "docker exec -it user-10.11.1.10 /bin/bash"
        ;;
    4)
        ssh -t ${VM_USER}@${VM_IP} "docker exec -it server-10.11.1.20 /bin/bash"
        ;;
    5)
        ssh ${VM_USER}@${VM_IP} "docker ps"
        ;;
    6)
        ssh ${VM_USER}@${VM_IP}
        ;;
    *)
        echo "Lua chon khong hop le!"
        ;;
esac

