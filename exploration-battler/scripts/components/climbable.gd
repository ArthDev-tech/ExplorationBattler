extends StaticBody3D

## =============================================================================
## Climbable - Climbable Surface Marker
## =============================================================================
## Marker component for climbable surfaces.
## Attach this script to StaticBody3D nodes that should allow ledge grabbing.
##
## The PlayerController's ledge grab system checks for this component
## to determine if a surface can be grabbed and climbed.
##
## For moving climbable platforms, use AnimatableBody3D with the
## MovingPlatform script (res://scripts/components/moving_platform.gd) instead.
## =============================================================================
