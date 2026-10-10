APP      := dist/MacSideKeyMacro.app
EXEC     := sidekey-macro

.PHONY: build app dmg run test clean

# 编译 release 版可执行文件
build:
	swift build -c release

# 打包成 dist/MacSideKeyMacro.app（含 Info.plist、图标、ad-hoc 签名）
app:
	./Scripts/package_app.sh release

# 生成 dist/MacSideKeyMacro-<版本>.dmg（拖进 Applications 的安装镜像）
dmg: app
	@VERSION="$$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' '$(APP)/Contents/Info.plist')"; \
	echo "==> 版本 $$VERSION"; \
	./Scripts/make_dmg.sh "$(APP)" "$$VERSION"

# 直接运行打包好的 App
run: app
	open "$(APP)"

# 运行解析器自测
test:
	swift build -c release
	.build/release/$(EXEC) --self-test

clean:
	rm -rf .build dist
