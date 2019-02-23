
.PHONY: test

clean-derived:
	rm -rf ~/Library/Developer/Xcode/DerivedData/EntropyKit*

clean:
	@echo "+ $@"
	@xcodebuild clean \
		-workspace EntropyKit.xcworkspace \
		-scheme EntropyKit-macOS
	@xcodebuild clean \
		-workspace EntropyKit.xcworkspace \
		-scheme EntropyKit-iOS

format:
	@echo "+ $@"
	@./Pods/SwiftFormat/CommandLineTool/swiftformat \
		--swiftversion '4.2' \
		Sources Tests
