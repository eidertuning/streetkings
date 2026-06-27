# Vehicle images

Local dealership and garage thumbnails are resolved from this folder by default.

Use one image per model:

```text
html/assets/vehicles/issi3.webp
html/assets/vehicles/t20.webp
```

To use externally hosted images, set `SKVehicleImageConfig.provider = 'jg'` and configure `jgBase`, or set an `image` override on a vehicle entry in `data/game_vehicles.lua`.
