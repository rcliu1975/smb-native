# smb-native (原生 Samba 服務設定指南)

使用主機作業系統的 Samba 服務直接分享資料夾（不使用 Docker），並透過密碼保護檔案安全。本說明文件提供手動安裝與設定的詳細步驟。

## 手動安裝與設定步驟

### 步驟 1：安裝 Samba 套件
```bash
sudo apt-get update
sudo apt-get install -y samba
```

### 步驟 2：建立或確定要分享的目錄
假設您要分享的 Unix 使用者為 `your_username`，其家目錄為 `/home/your_username`。如果該目錄不存在或需要建立新目錄，請執行：
```bash
# 建立目錄（如已存在則跳過）
mkdir -p /home/your_username

# 設定目錄擁有權限
sudo chown -R your_username:your_username /home/your_username
chmod 2775 /home/your_username
```

### 步驟 3：設定 Samba 密碼
為您要用來連線的 Unix 使用者設定 Samba 密碼：
```bash
sudo smbpasswd -a your_username
```
系統會提示您輸入並確認密碼（輸入時畫面不會顯示任何字元）。

### 步驟 4：設定 Samba 設定檔
在進行修改前，建議先備份原有的設定檔：
```bash
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
```

編輯 `/etc/samba/smb.conf`，將內容替換為以下設定（請將 `your_username` 與 `/home/your_username` 替換為實際的使用者名稱與分享路徑）：
```ini
[global]
   workgroup = WORKGROUP
   server string = Native Samba Server
   netbios name = %h
   security = user
   map to guest = never
   server min protocol = SMB2
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   load printers = no
   printcap name = /dev/null
   disable spoolss = yes
   usershare allow guests = no

[your_username]
   path = /home/your_username
   browseable = yes
   read only = no
   guest ok = no
   valid users = your_username
   create mask = 0664
   directory mask = 2775
```

### 步驟 5：驗證設定檔並啟動服務
1. 檢查設定檔語法是否正確：
   ```bash
   testparm
   ```
2. 啟動並啟用 Samba 服務，使其在開機時自動執行：
   ```bash
   sudo systemctl enable --now smbd nmbd
   sudo systemctl restart smbd nmbd
   ```

---

## 檢查狀態與連線方式

### 檢查服務狀態
您可以使用以下指令確認 Samba 服務是否正常運作：
```bash
sudo systemctl status smbd
sudo systemctl status nmbd
```

### 連線方式
在同一個區域網路下，使用以下方式連接：
* **Windows**: 在檔案總管網址列輸入 `\\<主機-IP>\<your_username>`
* **macOS / Linux**: 使用 `smb://<主機-IP>/<your_username>`

---

## 專案內附輔助腳本說明
如果您不想手動執行上述步驟，本專案仍保留了自動化腳本：
* `install-samba.sh`：自動執行上述所有手動步驟。
* `status-samba.sh`：快速檢查 Samba 的運作狀態與當前分享設定。
* `smb.conf.template`：用於自動化腳本的 Samba 設定樣板。

