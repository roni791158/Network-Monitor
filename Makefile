#
# Copyright (C) 2024 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=network-monitor
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/roni791158/Network-Monitor.git
PKG_SOURCE_VERSION:=HEAD
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_SOURCE_SUBDIR)

PKG_MAINTAINER:=Roni <roni791158@example.com>
PKG_LICENSE:=GPL-2.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/network-monitor
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Network Monitor with Web GUI
  DEPENDS:=+libnetfilter-log +libnetfilter-queue +iptables +kmod-ipt-NETFLOW +uhttpd +cgi-io +rpcd +rpcd-mod-uci +libiwinfo +luci-lib-json +luci-lib-nixio
  URL:=https://github.com/roni791158/Network-Monitor
endef

define Package/network-monitor/description
  Network monitoring package for OpenWrt with web interface.
  Features: Device detection, data usage tracking, website visit logging,
  and PDF report generation.
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/src \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)"
endef

define Package/network-monitor/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/netmon $(1)/usr/bin/
	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/netmon.init $(1)/etc/init.d/netmon
	
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/netmon.config $(1)/etc/config/netmon
	
	$(INSTALL_DIR) $(1)/www/netmon
	$(CP) ./files/www/* $(1)/www/netmon/
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/luci/controller/netmon.lua $(1)/usr/lib/lua/luci/controller/
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./files/luci/model/cbi/netmon.lua $(1)/usr/lib/lua/luci/model/cbi/
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/netmon
	$(CP) ./files/luci/view/netmon/* $(1)/usr/lib/lua/luci/view/netmon/
	
	$(INSTALL_DIR) $(1)/var/lib/netmon
	$(INSTALL_DIR) $(1)/var/log/netmon
endef

define Package/network-monitor/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/netmon enable
	/etc/init.d/netmon start
	/etc/init.d/uhttpd restart
}
endef

define Package/network-monitor/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/netmon stop
	/etc/init.d/netmon disable
}
endef

$(eval $(call BuildPackage,network-monitor))
