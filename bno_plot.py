import asyncio
import threading
import matplotlib
matplotlib.use("TkAgg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from bleak import BleakClient, BleakScanner
from collections import deque
import re
from time import sleep
from datetime import datetime
import csv
import tkinter as tk
from tkinter import ttk
import matplotlib.backends.backend_tkagg as tkagg

# === CONFIG ===
DEVICE_NAME = "JAMSHED_P"
CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8"
buffer_size = 100
smooth_window = 5
USE_SMOOTHING = True
csv_filename = "imu_log.csv"

# === Smoothing ===
def moving_average(data, window):
    if len(data) < window:
        return data
    return [sum(data[i - window:i]) / window for i in range(window, len(data) + 1)]


# === Kalman Filter Class ===
class KalmanFilter:
    def __init__(self, process_noise=1e-5, measurement_noise=1e-2, estimate_error=1.0):
        self.q = process_noise
        self.r = measurement_noise
        self.p = estimate_error
        self.x = 0.0

    def update(self, measurement):
        self.p += self.q
        k = self.p / (self.p + self.r)
        self.x += k * (measurement - self.x)
        self.p *= (1 - k)
        return self.x

# === Shared Buffers ===
shared_data = {
    "acc_x": deque(maxlen=buffer_size),
    "acc_y": deque(maxlen=buffer_size),
    "acc_z": deque(maxlen=buffer_size),
    "gyro_x": deque(maxlen=buffer_size),
    "gyro_y": deque(maxlen=buffer_size),
    "gyro_z": deque(maxlen=buffer_size),
    "vel_x": deque(maxlen=buffer_size),
    "vel_y": deque(maxlen=buffer_size),
    "vel_z": deque(maxlen=buffer_size),
}

kalman = {
    "vel_x": KalmanFilter(),
    "vel_y": KalmanFilter(),
    "vel_z": KalmanFilter(),
}

recording = True
lock = threading.Lock()
logfile = open(csv_filename, "w", newline="")
writer = csv.writer(logfile)
writer.writerow([
    "Time", "Acc X", "Acc Y", "Acc Z",
    "Gyro X", "Gyro Y", "Gyro Z",
    "Euler X", "Euler Y", "Euler Z",
    "Calib Sys", "Calib Gyro", "Calib Accel", "Calib Mag"
])

# === BLE Notification Handler ===
# === BLE Notification Handler ===
last_time = None
vel = [0.0, 0.0, 0.0]
alpha = 0.5  # Low-pass filter coefficient (0 = smoothest, 1 = raw)

# Previous raw acceleration for filtering
acc_prev = [0.0, 0.0, 0.0]

def notification_handler(sender, data):
    global recording, last_time, vel

    line = data.decode().strip()
    print(f"\n🔵 RAW: '{line}'")

    match = re.search(
        r"LinAcc X:(-?\d+\.\d+)LinAcc Y:(-?\d+\.\d+)LinAcc Z:(-?\d+\.\d+);"
        r"Gyro X:(-?\d+\.\d+)Gyro Y:(-?\d+\.\d+)Gyro Z:(-?\d+\.\d+);"
        r"Roll \(Euler X\):(-?\d+\.\d+)Pitch \(Euler Y\):(-?\d+\.\d+)Yaw \(Euler Z\):(-?\d+\.\d+);"
        r"Calib Sys:(\d+) Gyro:(\d+) Accel:(\d+) Mag:(\d+)",
        line
    )

    if match:
        now = datetime.now()
        if last_time is None:
            last_time = now

        dt = (now - last_time).total_seconds()
        last_time = now

        vals = [float(match.group(i)) for i in range(1, 10)]
        calib = [int(match.group(i)) for i in range(10, 14)]

        acc = vals[0:3]
        gyro = vals[3:6]

        # === Low-pass filter and clamping ===
        alpha = 0.5  # Place this inside the function
        acc_filtered = [alpha * a + (1 - alpha) * v for a, v in zip(acc, vel)]
        acc_clamped = [0.0 if abs(a) < 0.05 else a for a in acc_filtered]
        vel[:] = [v + a * dt for v, a in zip(vel, acc_clamped)]

        with lock:
            for axis, a in zip("xyz", acc):
                shared_data[f"acc_{axis}"].append(a)
            for axis, g in zip("xyz", gyro):
                shared_data[f"gyro_{axis}"].append(g)
            for axis, v_ in zip("xyz", vel):
                shared_data[f"vel_{axis}"].append(v_)

        if recording:
            timestamp = now.isoformat()
            writer.writerow([timestamp] + vals + calib)
            print("✅ Logged and appended")
    else:
        print("❌ No match")



# === BLE Thread ===
async def ble_loop():
    print("🔍 Scanning for device...")
    devices = await BleakScanner.discover()
    target = next((d for d in devices if d.name and DEVICE_NAME in d.name), None)

    if not target:
        print(f"❌ Device {DEVICE_NAME} not found")
        return

    async with BleakClient(target.address) as client:
        print(f"✅ Connected to {DEVICE_NAME}")
        await client.start_notify(CHARACTERISTIC_UUID, notification_handler)
        while True:
            await asyncio.sleep(1)

def start_ble_thread():
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(ble_loop())

# === Plot Setup ===
fig, axs = plt.subplots(3, 1, figsize=(8, 8))
plots = {
    "acc": axs[0],
    "gyro": axs[1],
    "vel": axs[2],
}

lines = {}
for key, ax in plots.items():
    ax.set_xlim(0, buffer_size)
    ax.set_ylim(-10, 10) if key != "acc" else ax.set_ylim(-2, 2)
    ax.set_title(key.upper())
    ax.grid(True)

lines["acc"] = [plots["acc"].plot([], [], label=axis)[0] for axis in "XYZ"]
lines["gyro"] = [plots["gyro"].plot([], [], label=axis)[0] for axis in "XYZ"]
lines["vel"] = [plots["vel"].plot([], [], label=axis)[0] for axis in "XYZ"]

for ax in axs:
    ax.legend()


def update(frame):
    with lock:
        acc = [list(shared_data[f"acc_{axis}"]) for axis in "xyz"]
        gyro = [list(shared_data[f"gyro_{axis}"]) for axis in "xyz"]
        vel = [list(shared_data[f"vel_{axis}"]) for axis in "xyz"]

    def safe_plot(ax, line_objs, data_group):
        ax.relim()
        ax.autoscale_view()
        for i in range(3):
            raw = data_group[i]
            if USE_SMOOTHING and len(raw) >= smooth_window:
                ydata = moving_average(raw, smooth_window)
                xdata = range(len(ydata))
            else:
                ydata = raw
                xdata = range(len(raw))
            line_objs[i].set_data(xdata, ydata)

    safe_plot(plots["acc"], lines["acc"], acc)
    safe_plot(plots["gyro"], lines["gyro"], gyro)
    safe_plot(plots["vel"], lines["vel"], vel)

    return sum(lines.values(), [])

# === Dashboard GUI ===
def toggle_recording():
    global recording
    recording = not recording
    record_btn.config(text="Pause Recording" if recording else "Resume Recording")

root = tk.Tk()
root.title("IMU BLE Dashboard")
record_btn = ttk.Button(root, text="Pause Recording", command=toggle_recording)
record_btn.pack(pady=10)

threading.Thread(target=start_ble_thread, daemon=True).start()
ani = FuncAnimation(fig, update, blit=False, interval=200)

canvas = tkagg.FigureCanvasTkAgg(fig, master=root)
canvas.draw()
canvas.get_tk_widget().pack(fill=tk.BOTH, expand=1)

root.protocol("WM_DELETE_WINDOW", lambda: (logfile.close(), root.destroy()))
root.mainloop()
