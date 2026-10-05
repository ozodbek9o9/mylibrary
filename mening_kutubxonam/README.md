# Mening Kutubxonam

## Windows uchun o'rnatuvchi tayyorlash

Windows kompyuterida Flutter va Visual Studio C++ build tools o'rnatilgan bo'lishi kerak.

1. Loyiha papkasida release build yarating:

	```powershell
	flutter build windows --release
	```

2. Inno Setup 6 ni o'rnating va `installer.iss` faylini Inno Setup Compiler'da ochib **Compile** bosing. Yoki terminalda:

	```powershell
	ISCC.exe installer.iss
	```

3. Tayyor o'rnatuvchi `dist\Mening_Kutubxonam-Setup-1.0.0.exe` manzilida bo'ladi. Boshqa kompyuterga yuborishda faqat shu Setup faylini yuboring; `mening_kutubxonam.exe`ning o'zini alohida yubormang.

O'rnatuvchi ilovaning `.dll` fayllari va `data` papkasini birga joylaydi, desktop va Start menyuga yorliq qo'shadi. Yangi Windows kompyuterida internet ulanishi va Microsoft Visual C++ Redistributable talab qilinishi mumkin.
