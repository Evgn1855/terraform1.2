#!/bin/bash

echo "=== Запуск полной очистки проекта Terraform ==="

# 1. Удаляем папки инициализации и кэша провайдеров
if [ -d ".terraform" ]; then
    rm -rf .terraform
    echo "[OK] Удалена папка .terraform"
fi

# 2. Удаляем lock-файл провайдеров
if [ -f ".terraform.lock.hcl" ]; then
    rm -f .terraform.lock.hcl
    echo "[OK] Удален файл .terraform.lock.hcl"
fi

# 3. Удаляем файлы состояния (state)
rm -f *.tfstate
rm -f *.tfstate.backup
rm -f *.tfstate.lock.info
echo "[OK] Удалены локальные файлы состояния (*.tfstate)"

# 4. Удаляем логи (если они велись)
rm -f *.log
echo "[OK] Удалены файлы логов (*.log)"

echo "=== Очистка завершена. Проект готов к отправке на GitHub! ==="