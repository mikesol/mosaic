module Feedback.LFOs where

import Prelude

import Feedback.Constants as C
import Feedback.FullGraph (FullGraph)
import Feedback.Types (Res)
import Type.Proxy (Proxy(..))
import WAGS.Change (ichange')
import WAGS.Control.Indexed (IxWAG)
import WAGS.Graph.Parameter (AudioEnvelope(..))
import WAGS.Run (RunAudio, RunEngine)

padSource2LFO :: Number -> forall proof. IxWAG RunAudio RunEngine proof Res FullGraph FullGraph Unit
padSource2LFO n = ichange' (Proxy :: _ "padSource2LFO")
  ( AudioEnvelope
      { duration: 10000.0 + (1.0 - n) * 15000.0
      , timeOffset: C.lfoTimeOffset
      , values: if n < 0.5 then C.longLFOU0 else if n < 0.75 then C.longLFOU1 else if n < 0.9 then C.longLFOU2 else C.longLFOU3
      }
  )

padSource3LFO :: Number -> forall proof. IxWAG RunAudio RunEngine proof Res FullGraph FullGraph Unit
padSource3LFO n = ichange' (Proxy :: _ "padSource3LFO")
  ( AudioEnvelope
      { duration: 6600.0 + (1.0 - n) * 20000.0
      , timeOffset: C.lfoTimeOffset
      , values: if n < 0.4 then C.longLFOU0 else if n < 0.6 then C.longLFOU1 else if n < 0.8 then C.longLFOU2 else C.longLFOU3
      }
  )

padSource4LFO :: Number -> forall proof. IxWAG RunAudio RunEngine proof Res FullGraph FullGraph Unit
padSource4LFO n = ichange' (Proxy :: _ "padSource4LFO")
  ( AudioEnvelope
      { duration: 2500.0 + (1.0 - n) * 20000.0
      , timeOffset: C.lfoTimeOffset
      , values: if n < 0.25 then C.longLFOU0 else if n < 0.5 then C.longLFOU1 else if n < 0.75 then C.longLFOU2 else C.longLFOU3
      }
  )

padSource0LFO :: Number -> forall proof. IxWAG RunAudio RunEngine proof Res FullGraph FullGraph Unit
padSource0LFO n = ichange' (Proxy :: _ "padSource0LFO")
  ( AudioEnvelope
      { duration: 20000.0 + (1.0 - n) * 15000.0
      , timeOffset: C.lfoTimeOffset
      , values: if n < 0.8 then C.longLFOU1 else if n < 0.94 then C.longLFOU2 else C.longLFOU3
      }
  )

padSource1LFO :: Number -> forall proof. IxWAG RunAudio RunEngine proof Res FullGraph FullGraph Unit
padSource1LFO n = ichange' (Proxy :: _ "padSource1LFO")
  ( AudioEnvelope
      { duration: 15000.0 + (1.0 - n) * 20000.0
      , timeOffset: C.lfoTimeOffset
      , values: if n < 0.7 then C.longLFOU0 else if n < 0.8 then C.longLFOU1 else if n < 0.9 then C.longLFOU2 else C.longLFOU3
      }
  )