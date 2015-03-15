# build paths
TOPDIR := .
BUILD_SYSTEM := $(TOPDIR)/build
BUILD_SCRIPT = $(BUILD_SYSTEM)/tools/build.sh


distclean:
	rm -fr $(TOP)/out

zImage :
	bash $(BUILD_SCRIPT) zImage

stuffs :
	bash $(BUILD_SCRIPT) all

#custom :
#	bash $(BUILD_SCRIPT) custom
