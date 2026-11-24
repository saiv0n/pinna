# Pretend notification server for scripts/e2e.sh; prints what it is asked to show.
import dbus, dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
name = dbus.service.BusName("org.freedesktop.Notifications", bus)
class N(dbus.service.Object):
    @dbus.service.method("org.freedesktop.Notifications", in_signature="susssasa{sv}i", out_signature="u")
    def Notify(self, app, rid, icon, title, body, actions, hints, timeout):
        print("NOTIFY", title, "|", body, flush=True); return 1
N(bus, "/org/freedesktop/Notifications")
GLib.MainLoop().run()
