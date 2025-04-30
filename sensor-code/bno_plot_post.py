import asyncio
import threading
import matplotlib
matplotlib.use("TkAgg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from bleak import BleakClient, BleakScanner
from collections import deque
from datetime import datetime
import tkinter as tk
from tkinter import ttk
import matplotlib.backends.backend_tkagg as tkagg
import json
import struct

# === CONFIG ===
DEVICE_NAME = "sheeeeeed"
CHARACTERISTIC_UUID = "207a2a33-ab38-4748-8702-5ff50b2d673f"
COMMAND_CHARACTERISTIC_UUID = "1c902c8d-88bb-44f9-9dea-0bc5bf2d0af4"
BUFFER_SIZE = 1000
SMOOTH_WINDOW = 5
USE_SMOOTHING = True

# === Shared State ===
shared_data = {
    "time": [],
    "velocity": [],
    "accel": [],
    "pitch": [],
    "yaw": []
}

lock = threading.Lock()
client = None
recording = False
received_stop = False
ble_loop_handle = None  # global loop handle

# === BLE Notification Handler ===
def notification_handler(sender, data):
    global received_stop
    try:
        if len(data) != 10:
            print(f"❌ Unexpected packet size: {len(data)} bytes")
            return

        dt_ms, velocity_raw, accel_raw, pitch_raw, yaw_raw = struct.unpack("<Hhhhh", data)

        velocity = velocity_raw / 1000.0
        accel = accel_raw / 100.0
        pitch = pitch_raw / 100.0
        yaw = yaw_raw / 100.0

        with lock:
            shared_data["time"].append(dt_ms / 1000.0)  # convert to seconds
            shared_data["velocity"].append(velocity)
            shared_data["accel"].append(accel)
            shared_data["pitch"].append(pitch)
            shared_data["yaw"].append(yaw)

        print(f"📥 Received | dt: {dt_ms} ms | vel: {velocity:.3f} m/s | acc: {accel:.2f} m/s²")

    except Exception as e:
        print(f"❌ Error in notification handler: {e}")

# === BLE Functions ===
async def ble_loop():
    global client, recording
    print("🔍 Scanning for device...")
    devices = await BleakScanner.discover()
    target = next((d for d in devices if d.name and DEVICE_NAME in d.name), None)

    if not target:
        print(f"❌ Device {DEVICE_NAME} not found.")
        return

    client = BleakClient(target.address)
    async with client:
        print(f"✅ Connected to {DEVICE_NAME}")
        await client.start_notify(CHARACTERISTIC_UUID, notification_handler)

        await client.write_gatt_char(COMMAND_CHARACTERISTIC_UUID, b"start", response=True)
        print("🟢 Started recording...")
        recording = True

        try:
            while True:
                await asyncio.sleep(0.5)
        except asyncio.CancelledError:
            pass

async def send_stop_command():
    global recording, received_stop
    if client and client.is_connected:
        await client.write_gatt_char(COMMAND_CHARACTERISTIC_UUID, b"stop", response=True)
        print("🛑 Stop command sent!")
        recording = False
        received_stop = True
    else:
        print("⚠️ BLE client not connected.")

# === Threaded BLE Start ===
def start_ble_thread():
    global ble_loop_handle
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    ble_loop_handle = loop
    loop.run_until_complete(ble_loop())

# === GUI Actions ===
def manual_stop():
    global ble_loop_handle
    if ble_loop_handle and ble_loop_handle.is_running():
        asyncio.run_coroutine_threadsafe(send_stop_command(), ble_loop_handle)
    else:
        print("⚠️ No BLE loop running.")

def exit_app():
    root.destroy()

# === Plot Setup ===
fig, axs = plt.subplots(2, 1, figsize=(8, 8))
plot_vel, = axs[0].plot([], [], label="Velocity (m/s)")
plot_acc, = axs[1].plot([], [], label="Acceleration (m/s²)")

axs[0].set_ylabel("Velocity (m/s)")
axs[0].set_ylim(-1.0, 1.0)   # FIXED bounds for velocity graph
axs[1].set_ylabel("Acceleration (m/s²)")
axs[1].set_ylim(-5.0, 5.0)   # FIXED bounds for accel graph
axs[1].set_xlabel("Time (s)")

for ax in axs:
    ax.grid(True)
    ax.legend()


def update(frame):
    if received_stop:
        with lock:
            if len(shared_data["time"]) > 1:
                plot_vel.set_data(shared_data["time"], shared_data["velocity"])
                plot_acc.set_data(shared_data["time"], shared_data["accel"])

                axs[0].relim()
                axs[0].autoscale_view()
                axs[1].relim()
                axs[1].autoscale_view()
    return plot_vel, plot_acc

# === TKinter Dashboard ===
root = tk.Tk()
root.title("IMU BLE Dashboard")

record_btn = ttk.Button(root, text="Send STOP", command=manual_stop)
record_btn.pack(pady=10)

canvas = tkagg.FigureCanvasTkAgg(fig, master=root)
canvas.draw()
canvas.get_tk_widget().pack(fill=tk.BOTH, expand=1)

threading.Thread(target=start_ble_thread, daemon=True).start()
ani = FuncAnimation(fig, update, blit=False, interval=500)

root.protocol("WM_DELETE_WINDOW", exit_app)
root.mainloop()
