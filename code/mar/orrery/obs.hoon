::  mar/orrery/obs: one observation, at /bodies/<kind>/<slug>/obs/<oid>.
::
::    Stored as [%1 obs]. Immutable except for the retracted flag. A
::    noun passthrough; the shape ladder is +read-obs in lib/orrery.
::
|_  n=*
++  grad  %noun
++  grow
  |%
  ++  noun  n
  --
++  grab
  |%
  ++  noun  *
  --
--
