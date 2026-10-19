::  mar/orrery/current: the current view, at /current.noun (version 119).
::
::    Stored as [%1 fold multi bodies] (see +stored-current in
::    lib/orrery). A noun passthrough: +read-current molds it, and a
::    shape it cannot read is only a cache to build again.
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
