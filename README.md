
# OSRM Profiles customization

## Branches hierarchy


Based on [OSRM](https://github.com/Project-OSRM/osrm-backend/) car profiles.

`master` branch follows OSRM default car profiles.

`common` branch follows `master` branch, and content common customization.

`car-interurban` branch follows `common` for interurban ride.

`car-urban` branch follows `car-interurban` adjusted for urban ride.

`car` branch follows `common`, auto adjust speed based on land use.

`car-distance` branch follows `car` but for smart-shortest routing.

`truck-medium` branch follows `car` but for small truck.


```
master - OSRM-Car
└── common
    ├── car-interurban
    │   └── car-urban
    └── car
        ├── car-distance
        ├── scooter
        └── truck-medium
```

## Features

Main features included in this project can also be found in [osrm-profiles-contrib](https://github.com/Project-OSRM/osrm-profiles-contrib).

## License

Copyright © 2018 Project OSRM Contributors, Mapotempo

Distributed under the MIT License (MIT).
