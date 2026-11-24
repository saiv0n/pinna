# Pretend media player for scripts/e2e.sh; prints the calls it gets.
import dbus, dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
name = dbus.service.BusName("org.mpris.MediaPlayer2.mock", bus)
P = "org.mpris.MediaPlayer2.Player"
class M(dbus.service.Object):
    status = "Playing"
    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="ss", out_signature="v")
    def Get(self, i, p):
        return {"PlaybackStatus": self.status}.get(p, "")
    @dbus.service.method("org.freedesktop.DBus.Properties", in_signature="s", out_signature="a{sv}")
    def GetAll(self, i): return {"PlaybackStatus": self.status}
    @dbus.service.method(P)
    def Pause(self): self.status = "Paused"; print("PAUSE", flush=True)
    @dbus.service.method(P)
    def Play(self): self.status = "Playing"; print("PLAY", flush=True)
    @dbus.service.method(P)
    def PlayPause(self): print("PLAYPAUSE", flush=True)
M(bus, "/org/mpris/MediaPlayer2")
GLib.MainLoop().run()
