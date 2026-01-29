# Patrol path (Marker3D waypoints)

1. Add a **Node3D** as a child of the enemy and name it **PatrolPath**.
2. Add **Marker3D** nodes as children of PatrolPath (one per waypoint). Order in the scene tree = patrol order.
3. Move the markers in the 3D viewport to shape the path. If no PatrolPath exists, the enemy uses the **Patrol Points** export or the default 5-unit segment.
