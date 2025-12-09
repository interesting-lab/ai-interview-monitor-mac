.PHONY: build run run-gui run-cli debug debug-gui debug-cli clean install

APP_NAME = 拾问AI助手-monitor
BUILD_DIR = .build
INSTALL_DIR = /Applications

build:
	swift build --configuration release

run: build
	.build/release/$(APP_NAME)

run-gui: build
	.build/release/$(APP_NAME)

run-cli: build
	.build/release/$(APP_NAME) --cli

debug:
	swift build
	.build/debug/$(APP_NAME)

debug-gui:
	swift build
	.build/debug/$(APP_NAME)

debug-cli:
	swift build
	.build/debug/$(APP_NAME) --cli

clean:
	swift package clean
	rm -rf $(BUILD_DIR)

install: build
	mkdir -p $(INSTALL_DIR)/$(APP_NAME).app/Contents/MacOS
	mkdir -p $(INSTALL_DIR)/$(APP_NAME).app/Contents/Resources
	cp .build/release/$(APP_NAME) $(INSTALL_DIR)/$(APP_NAME).app/Contents/MacOS/
	cp Info.plist $(INSTALL_DIR)/$(APP_NAME).app/Contents/
	chmod +x $(INSTALL_DIR)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)

package: build
	mkdir -p $(APP_NAME).app/Contents/MacOS
	mkdir -p $(APP_NAME).app/Contents/Resources
	cp .build/release/$(APP_NAME) $(APP_NAME).app/Contents/MacOS/
	cp Info.plist $(APP_NAME).app/Contents/
	chmod +x $(APP_NAME).app/Contents/MacOS/$(APP_NAME)

test:
	curl -s http://localhost:9047/health | python3 -m json.tool

test-config:
	curl -s http://localhost:9047/config | python3 -m json.tool

help:
	@echo "可用命令:"
	@echo "  build       - 编译应用"
	@echo "  run         - 编译并运行应用 (默认GUI模式)"
	@echo "  run-gui     - 编译并运行GUI应用"
	@echo "  run-cli     - 编译并运行命令行版本"
	@echo "  debug       - 编译调试版本并运行 (默认GUI模式)"
	@echo "  debug-gui   - 编译调试版本并运行GUI"
	@echo "  debug-cli   - 编译调试版本并运行命令行"
	@echo "  clean       - 清理编译文件"
	@echo "  install     - 安装到应用程序文件夹"
	@echo "  package     - 创建.app包"
	@echo "  test        - 测试health端点"
	@echo "  test-config - 测试config端点" 