::  mar/orrery/body: one body, at /bodies/<kind>/<slug>/body.
::
::    Stored as [%2 body] (see +stored-body in lib/orrery); the reader
::    lifts an older [%1 body]. A noun passthrough: the shape ladder
::    lives in +read-body, so a later shape never booms a stored grub.
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
