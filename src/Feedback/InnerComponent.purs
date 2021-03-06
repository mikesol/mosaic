module Feedback.InnerComponent where

import Prelude

import Control.Alt ((<|>))
import Data.Array ((..))
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.Newtype (unwrap, wrap)
import Data.Profunctor (lcmap)
import Data.Traversable (for_)
import Data.Tuple (fst, snd)
import Data.Tuple.Nested (type (/\), (/\))
import Data.Typelevel.Num (D2, D3, D4, D5)
import Data.Variant (default, inj, onMatch, match, prj)
import Data.Vec ((+>), empty)
import Effect (Effect)
import Effect.Aff.Class (class MonadAff)
import Effect.Class (class MonadEffect)
import Effect.Class.Console as Log
import FRP.Event (Event, EventIO, filterMap, subscribe)
import FRP.Event.Time (interval)
import Feedback.Acc (initialAcc)
import Feedback.Control (Action(..), HereThere(..), MusicalAction(..), PadAction(..), SliderAction(..), State, T2(..), T3(..), T4(..), T5(..), c2s, elts, hashCode, normalizedWidthAndHeightSvg, reverseS)
import Feedback.Engine (piece)
import Feedback.Oracle (oracle)
import Feedback.PubNub (PubNub, PubNubEvent(..), PubNubMessage(..), UIEvent(..), publish)
import Feedback.Setup (setup)
import Feedback.Types (Bang(..), Buffers, Elts(..), IncomingEvent, IncomingEvent', Res, Trigger(..), ZeroToOne(..), PadT, ezto, nFromZeroOne)
import Foreign.Object (fromHomogeneous, values)
import Foreign.Object as Object
import Halogen (ClassName(..))
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Subscription as HS
import Halogen.Svg.Attributes (Color(..))
import Halogen.Svg.Attributes as SA
import Halogen.Svg.Elements as SE
import Math (abs, pi)
import Type.Proxy (Proxy(..))
import WAGS.Interpret (close, context, makeFFIAudioSnapshot, makeFloatArray, makePeriodicWave)
import WAGS.Run (TriggeredRun, runNoLoop)

component :: forall query input output m. MonadEffect m => MonadAff m => Event PubNubEvent -> EventIO (HereThere /\ IncomingEvent) -> PubNub -> Buffers -> H.Component query input output m
component remoteEvent localEvent pubnub buffers =
  H.mkComponent
    { initialState
    , render
    , eval: H.mkEval $ H.defaultEval
        { handleAction = handleAction remoteEvent localEvent pubnub buffers
        }
    }

initialState :: forall input. input -> State
initialState _ =
  { unsubscribe: pure unit
  , audioCtx: Nothing
  , unsubscribeHalogen: Nothing
  , mice: Object.empty
  , interactions:
      { gainLFO0Pad: 0.0
      , gainLFO0PadDown: false
      , gainLFO1Pad: 0.0
      , gainLFO1PadDown: false
      , waveshaperPad: 0.0
      , waveshaperPadDown: false
      , pitchLead: 0.0
      , pitchLeadDown: false
      , leadDelayGainCarousel: 0.0
      , leadDelayGainCarouselDown: false
      , nPitchesPlayedLead: 0.0
      , nPitchesPlayedLeadDown: false
      , droneLowpass0Q: 0.0
      , droneLowpass0QDown: false
      , droneBandpass0Q: 0.0
      , droneBandpass0QDown: false
      , droneBandpass0LFO: 0.0
      , droneBandpass0LFODown: false
      , droneBandpass1Q: 0.0
      , droneBandpass1QDown: false
      , droneBandpass1LFO: 0.0
      , droneBandpass1LFODown: false
      , droneHighpass0Q: 0.0
      , droneHighpass0QDown: false
      , droneHighpass0LFO: 0.0
      , droneHighpass0LFODown: false
      , droneActivationEnergyThreshold: 0.0
      , droneActivationEnergyThresholdDown: false
      , droneDecay: 0.0
      , droneDecayDown: false
      , sampleChooser: 0.0
      , sampleChooserDown: false
      , sampleDelayGainCarousel: 0.0
      , sampleDelayGainCarouselDown: false
      , loopingBufferStartEndConstriction: 0.0
      , loopingBufferStartEndConstrictionDown: false
      , greatAndMightyPan: 0.0
      , greatAndMightyPanDown: false
      , distantBellsFader: 0.0
      , distantBellsFaderDown: false
      --
      , togglePadOsc0: T2_1
      , togglePadOsc1: T2_0
      , togglePadOsc2: T2_1
      , togglePadOsc3: T2_0
      , togglePadOsc4: T2_0
      , leadDelayLine0: T2_0
      , leadDelayLine1: T2_0
      , leadDelayLine2: T2_0
      , leadCombinedDelay0: T2_0
      , droneFlange: T2_0
      , sampleReverse: T2_0
      , sampleChorusEffect: T2_0
      , sampleDelayLine0: T2_0
      , sampleDelayLine1: T2_0
      , sampleDelayLine2: T2_0
      , sampleCombinedDelayLine0: T2_0
      , leadSampleDelayLine0: T2_0
      , leadSampleDelayLine1: T2_0
      , leadSampleDelayLine2: T2_0
      , loopingBufferGainDJ: T2_0
      , loopingBuffer0: T2_0
      , loopingBuffer1: T2_0
      , loopingBuffer2: T2_0
      , loopingBuffer3: T2_0
      , loopingBuffer4: T2_0
      , radicalFlip: T2_0
      , globalDelay: T2_0
      --
      , envelopeLead: T3_0
      , octaveLead: T3_0
      , sampleRateChange: T3_0
      --
      , detunePad: T4_0
      --
      , filterBankChooserPad: T5_0
      , droneChooser: T5_0
      , droneRhythmicLoopingPiecewiseFunction: T5_0
      , synthForLead: T5_0
      --
      , triggerPad: 0.0
      , triggerPadUp: false
      , drone: 0.0
      , droneUp: false
      --
      , echoingUncontrollableSingleton: false
      , triggerLead: false
      , sampleOneShot: false
      }
  }

classes :: forall r p. Array String -> HP.IProp (class :: String | r) p
classes = HP.classes <<< map H.ClassName

render :: forall m. State -> H.ComponentHTML Action () m
render st = case st.audioCtx of
  Nothing -> HH.div [ HP.classes $ map ClassName [ "w-full", "h-full" ] ]
    [ HH.div [ classes [ "flex", "flex-col", "w-full", "h-full" ] ]
        [ HH.div [ classes [ "flex-grow" ] ] [ HH.div_ [] ]
        , HH.div [ classes [ "flex-grow-0", "flex", "flex-row" ] ]
            [ HH.div [ classes [ "flex-grow" ] ]
                []
            , HH.div [ classes [ "flex", "flex-col" ] ]

                [ HH.h1 [ classes [ "text-center", "text-3xl", "font-bold" ] ]
                    [ HH.text "Loaded! Ready when you are..."
                    ]
                , HH.button
                    [ classes [ "text-2xl", "m-5", "bg-indigo-500", "p-3", "rounded-lg", "text-white", "hover:bg-indigo-400" ], HE.onClick \_ -> StartAudio ]
                    [ HH.text "Start audio" ]
                ]
            , HH.div [ classes [ "flex-grow" ] ] []
            ]
        , HH.div [ classes [ "flex-grow" ] ] []
        ]
    ]
  Just _ -> SE.svg
    [ SA.classes $ map ClassName [ "w-full", "h-full" ]
    , SA.viewBox 0.0 0.0 1000.0 1000.0
    , SA.preserveAspectRatio Nothing SA.Slice
    , HE.onMouseMove $ lcmap normalizedWidthAndHeightSvg MouseMove
    ]
    [ SE.g [] (join $ map (c2s st) $ values $ fromHomogeneous elts)
    , SE.g [] (map (\(ix /\ v) -> SE.circle [ SA.cx (1000.0 * v.x), SA.cy (1000.0 * v.y), SA.r 8.0, SA.fill (RGB (hashCode ix `mod` 256) (hashCode (reverseS ix) `mod` 256) 0) ]) $ Object.toUnfoldable $ st.mice)
    ]

makeDistortionCurve :: Number -> Array Number
makeDistortionCurve k =
  map
    ( \i ->
        let
          x = (toNumber i * 2.0 / toNumber n_samples) - 1.0
        in
          (3.0 + k) * x * 20.0 * deg / (pi + (k * abs x))
    )
    (0 .. (n_samples - 1))
  where
  n_samples = 44100

  deg = pi / 180.0

dc :: Array Number
dc = makeDistortionCurve 440.0

handleT5
  :: forall output m
   . MonadEffect m
  => MonadAff m
  => (IncomingEvent -> Effect Unit)
  -> (State -> T5 -> State)
  -- not used currently...
  -> (State -> T5)
  -> (Elts D5 -> IncomingEvent')
  -> T5
  -> H.HalogenM State Action () output m Unit
handleT5 push f _ mv t5 = do
  H.modify_ (\s -> f s t5)
  H.liftEffect $ push $ wrap $ mv $ case t5 of
    T5_0 -> Elts 0
    T5_1 -> Elts 1
    T5_2 -> Elts 2
    T5_3 -> Elts 3
    T5_4 -> Elts 4

handleT4
  :: forall output m
   . MonadEffect m
  => MonadAff m
  => (IncomingEvent -> Effect Unit)
  -> (State -> T4 -> State)
  -- not used currently...
  -> (State -> T4)
  -> (Elts D4 -> IncomingEvent')
  -> T4
  -> H.HalogenM State Action () output m Unit
handleT4 push f _ mv t4 = do
  H.modify_ (\s -> f s t4)
  H.liftEffect $ push $ wrap $ mv $ case t4 of
    T4_0 -> Elts 0
    T4_1 -> Elts 1
    T4_2 -> Elts 2
    T4_3 -> Elts 3

handleT3
  :: forall output m
   . MonadEffect m
  => MonadAff m
  => (IncomingEvent -> Effect Unit)
  -> (State -> T3 -> State)
  -- not used currently...
  -> (State -> T3)
  -> (Elts D3 -> IncomingEvent')
  -> T3
  -> H.HalogenM State Action () output m Unit
handleT3 push f _ mv t3 = do
  H.modify_ (\s -> f s t3)
  H.liftEffect $ push $ wrap $ mv $ case t3 of
    T3_0 -> Elts 0
    T3_1 -> Elts 1
    T3_2 -> Elts 2

handleT2
  :: forall output m
   . MonadEffect m
  => MonadAff m
  => (IncomingEvent -> Effect Unit)
  -> (State -> T2 -> State)
  -- not used currently...
  -> (State -> T2)
  -> (Elts D2 -> IncomingEvent')
  -> T2
  -> H.HalogenM State Action () output m Unit
handleT2 push f _ mv t2 = do
  H.modify_ (\s -> f s t2)
  H.liftEffect $ push $ wrap $ mv $ case t2 of
    T2_0 -> Elts 0
    T2_1 -> Elts 1

handleSlider
  :: forall output m
   . MonadEffect m
  => MonadAff m
  => (IncomingEvent -> Effect Unit)
  -> (State -> Number -> Boolean -> State)
  -> (State -> Boolean)
  -> (State -> Number)
  -> (Number -> IncomingEvent')
  -> SliderAction
  -> H.HalogenM State Action () output m Unit
handleSlider push f _ _ mv (SliderDown n) = do
  H.modify_ (\s -> f s n true)
  H.liftEffect $ push (wrap $ mv n)
handleSlider push f fb _ mv (SliderMove n) = do
  pressed <- H.gets fb
  when pressed do
    H.modify_ (\s -> f s n true)
    H.liftEffect $ push (wrap $ mv n)
handleSlider _ f _ fn _ SliderUp = do
  H.modify_ (\s -> f s (fn s) false)
handleSlider push f fb _ mv (SliderRemoteMove n) = do
  H.modify_ (\s -> f s n (fb s))
  H.liftEffect $ push (wrap $ mv n)

clamp01 :: Number -> ZeroToOne
clamp01 n =
  ZeroToOne do
    if n < 0.0 then 0.0 else if n > 1.0 then 1.0 else n

uzto :: ZeroToOne -> Number
uzto (ZeroToOne n) = n

et2 :: Elts D2 -> T2
et2 (Elts n) = case n of
  0 -> T2_0
  _ -> T2_1

et3 :: Elts D3 -> T3
et3 (Elts n) = case n of
  0 -> T3_0
  1 -> T3_1
  _ -> T3_2

et4 :: Elts D4 -> T4
et4 (Elts n) = case n of
  0 -> T4_0
  1 -> T4_1
  2 -> T4_2
  _ -> T4_3

et5 :: Elts D5 -> T5
et5 (Elts n) = case n of
  0 -> T5_0
  1 -> T5_1
  2 -> T5_2
  3 -> T5_3
  _ -> T5_4

usingHT :: HereThere -> ((HereThere /\ IncomingEvent) -> Effect Unit) -> IncomingEvent -> Effect Unit
usingHT ht f i = f (ht /\ i)

handleAction :: forall output m. MonadEffect m => MonadAff m => Event PubNubEvent -> EventIO (HereThere /\ IncomingEvent) -> PubNub -> Buffers -> Action -> H.HalogenM State Action () output m Unit
handleAction remoteEvent localEvent pubnub buffers = case _ of
  MusicalAction hereOrThere thing ->
    let
      newPush = usingHT hereOrThere localEvent.push
    in
      case thing of
        GainLFO0Pad sliderAction -> handleSlider
          newPush
          _ { interactions { gainLFO0Pad = _, gainLFO0PadDown = _ } }
          _.interactions.gainLFO0PadDown
          _.interactions.gainLFO0Pad
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "gainLFO0Pad"
              )
          )
          sliderAction
        GainLFO1Pad sliderAction -> handleSlider
          newPush
          _ { interactions { gainLFO1Pad = _, gainLFO1PadDown = _ } }
          _.interactions.gainLFO1PadDown
          _.interactions.gainLFO1Pad
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "gainLFO1Pad"
              )
          )
          sliderAction
        WaveshaperPad sliderAction -> handleSlider
          newPush
          _ { interactions { waveshaperPad = _, waveshaperPadDown = _ } }
          _.interactions.waveshaperPadDown
          _.interactions.waveshaperPad
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "waveshaperPad"
              )
          )
          sliderAction
        PitchLead sliderAction -> handleSlider
          newPush
          _ { interactions { pitchLead = _, pitchLeadDown = _ } }
          _.interactions.pitchLeadDown
          _.interactions.pitchLead
          ( clamp01 >>> nFromZeroOne >>> inj
              ( Proxy
                  :: Proxy
                       "pitchLead"
              )
          )
          sliderAction
        LeadDelayGainCarousel sliderAction -> handleSlider
          newPush
          _ { interactions { leadDelayGainCarousel = _, leadDelayGainCarouselDown = _ } }
          _.interactions.leadDelayGainCarouselDown
          _.interactions.leadDelayGainCarousel
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "leadDelayGainCarousel"
              )
          )
          sliderAction
        NPitchesPlayedLead sliderAction -> handleSlider
          newPush
          _ { interactions { nPitchesPlayedLead = _, nPitchesPlayedLeadDown = _ } }
          _.interactions.nPitchesPlayedLeadDown
          _.interactions.nPitchesPlayedLead
          ( clamp01 >>> nFromZeroOne >>> inj
              ( Proxy
                  :: Proxy
                       "nPitchesPlayedLead"
              )
          )
          sliderAction
        DroneLowpass0Q sliderAction -> handleSlider
          newPush
          _ { interactions { droneLowpass0Q = _, droneLowpass0QDown = _ } }
          _.interactions.droneLowpass0QDown
          _.interactions.droneLowpass0Q
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "droneLowpass0Q"
              )
          )
          sliderAction
        DroneBandpass0Q sliderAction -> handleSlider
          newPush
          _ { interactions { droneBandpass0Q = _, droneBandpass0QDown = _ } }
          _.interactions.droneBandpass0QDown
          _.interactions.droneBandpass0Q
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "droneBandpass0Q"
              )
          )
          sliderAction
        DroneBandpass0LFO sliderAction -> handleSlider
          newPush
          _ { interactions { droneBandpass0LFO = _, droneBandpass0LFODown = _ } }
          _.interactions.droneBandpass0LFODown
          _.interactions.droneBandpass0LFO
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "droneBandpass0LFO"
              )
          )
          sliderAction
        DroneBandpass1Q sliderAction -> handleSlider
          newPush
          _ { interactions { droneBandpass1Q = _, droneBandpass1QDown = _ } }
          _.interactions.droneBandpass1QDown
          _.interactions.droneBandpass1Q
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "droneBandpass1Q"
              )
          )
          sliderAction
        DroneBandpass1LFO sliderAction -> handleSlider
          newPush
          _ { interactions { droneBandpass1LFO = _, droneBandpass1LFODown = _ } }
          _.interactions.droneBandpass1LFODown
          _.interactions.droneBandpass1LFO
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "droneBandpass1LFO"
              )
          )
          sliderAction
        DroneHighpass0Q sliderAction -> handleSlider
          newPush
          _ { interactions { droneHighpass0Q = _, droneHighpass0QDown = _ } }
          _.interactions.droneHighpass0QDown
          _.interactions.droneHighpass0Q
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "droneHighpass0Q"
              )
          )
          sliderAction
        DroneHighpass0LFO sliderAction -> handleSlider
          newPush
          _ { interactions { droneHighpass0LFO = _, droneHighpass0LFODown = _ } }
          _.interactions.droneHighpass0LFODown
          _.interactions.droneHighpass0LFO
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "droneHighpass0LFO"
              )
          )
          sliderAction
        DroneActivationEnergyThreshold sliderAction -> handleSlider
          newPush
          _ { interactions { droneActivationEnergyThreshold = _, droneActivationEnergyThresholdDown = _ } }
          _.interactions.droneActivationEnergyThresholdDown
          _.interactions.droneActivationEnergyThreshold
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "droneActivationEnergyThreshold"
              )
          )
          sliderAction
        DroneDecay sliderAction -> handleSlider
          newPush
          _ { interactions { droneDecay = _, droneDecayDown = _ } }
          _.interactions.droneDecayDown
          _.interactions.droneDecay
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "droneDecay"
              )
          )
          sliderAction
        SampleChooser sliderAction -> handleSlider
          newPush
          _ { interactions { sampleChooser = _, sampleChooserDown = _ } }
          _.interactions.sampleChooserDown
          _.interactions.sampleChooser
          ( clamp01 >>> nFromZeroOne >>> inj
              ( Proxy
                  :: Proxy
                       "sampleChooser"
              )
          )
          sliderAction
        SampleDelayGainCarousel sliderAction -> handleSlider
          newPush
          _ { interactions { sampleDelayGainCarousel = _, sampleDelayGainCarouselDown = _ } }
          _.interactions.sampleDelayGainCarouselDown
          _.interactions.sampleDelayGainCarousel
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "sampleDelayGainCarousel"
              )
          )
          sliderAction
        LoopingBufferStartEndConstriction sliderAction -> handleSlider
          newPush
          _ { interactions { loopingBufferStartEndConstriction = _, loopingBufferStartEndConstrictionDown = _ } }
          _.interactions.loopingBufferStartEndConstrictionDown
          _.interactions.loopingBufferStartEndConstriction
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "loopingBufferStartEndConstriction"
              )
          )
          sliderAction
        GreatAndMightyPan sliderAction -> handleSlider
          newPush
          _ { interactions { greatAndMightyPan = _, greatAndMightyPanDown = _ } }
          _.interactions.greatAndMightyPanDown
          _.interactions.greatAndMightyPan
          ( clamp01 >>> inj
              ( Proxy
                  :: Proxy
                       "greatAndMightyPan"
              )
          )
          sliderAction
        DistantBellsFader sliderAction -> handleSlider
          newPush
          _ { interactions { distantBellsFader = _, distantBellsFaderDown = _ } }
          _.interactions.distantBellsFaderDown
          _.interactions.distantBellsFader
          (clamp01 >>> inj (Proxy :: Proxy "distantBellsFader"))
          sliderAction
        --
        TogglePadOsc0 t2 -> handleT2 newPush _ { interactions { togglePadOsc0 = _ } } _.interactions.togglePadOsc0
          (inj (Proxy :: Proxy "togglePadOsc0"))
          t2
        TogglePadOsc1 t2 -> handleT2 newPush _ { interactions { togglePadOsc1 = _ } } _.interactions.togglePadOsc1
          (inj (Proxy :: Proxy "togglePadOsc1"))
          t2
        TogglePadOsc2 t2 -> handleT2 newPush _ { interactions { togglePadOsc2 = _ } } _.interactions.togglePadOsc2
          (inj (Proxy :: Proxy "togglePadOsc2"))
          t2
        TogglePadOsc3 t2 -> handleT2 newPush _ { interactions { togglePadOsc3 = _ } } _.interactions.togglePadOsc3
          (inj (Proxy :: Proxy "togglePadOsc3"))
          t2
        TogglePadOsc4 t2 -> handleT2 newPush _ { interactions { togglePadOsc4 = _ } } _.interactions.togglePadOsc4
          (inj (Proxy :: Proxy "togglePadOsc4"))
          t2
        LeadDelayLine0 t2 -> handleT2 newPush _ { interactions { leadDelayLine0 = _ } } _.interactions.leadDelayLine0
          ( inj (Proxy :: Proxy "leadDelayLine0")
          )
          t2
        LeadDelayLine1 t2 -> handleT2 newPush _ { interactions { leadDelayLine1 = _ } } _.interactions.leadDelayLine1
          (inj (Proxy :: Proxy "leadDelayLine1"))
          t2
        LeadDelayLine2 t2 -> handleT2 newPush _ { interactions { leadDelayLine2 = _ } } _.interactions.leadDelayLine2
          (inj (Proxy :: Proxy "leadDelayLine2"))
          t2
        LeadCombinedDelay0 t2 -> handleT2 newPush _ { interactions { leadCombinedDelay0 = _ } } _.interactions.leadCombinedDelay0
          (inj (Proxy :: Proxy "leadCombinedDelay0"))
          t2
        DroneFlange t2 -> handleT2 newPush _ { interactions { droneFlange = _ } } _.interactions.droneFlange
          (inj (Proxy :: Proxy "droneFlange"))
          t2
        SampleReverse t2 -> handleT2 newPush _ { interactions { sampleReverse = _ } } _.interactions.sampleReverse
          (inj (Proxy :: Proxy "sampleReverse"))
          t2
        SampleChorusEffect t2 -> handleT2 newPush _ { interactions { sampleChorusEffect = _ } } _.interactions.sampleChorusEffect
          (inj (Proxy :: Proxy "sampleChorusEffect"))
          t2
        SampleDelayLine0 t2 -> handleT2 newPush _ { interactions { sampleDelayLine0 = _ } } _.interactions.sampleDelayLine0
          (inj (Proxy :: Proxy "sampleDelayLine0"))
          t2
        SampleDelayLine1 t2 -> handleT2 newPush _ { interactions { sampleDelayLine1 = _ } } _.interactions.sampleDelayLine1
          (inj (Proxy :: Proxy "sampleDelayLine1"))
          t2
        SampleDelayLine2 t2 -> handleT2 newPush _ { interactions { sampleDelayLine2 = _ } } _.interactions.sampleDelayLine2
          (inj (Proxy :: Proxy "sampleDelayLine2"))
          t2
        SampleCombinedDelayLine0 t2 -> handleT2 newPush _ { interactions { sampleCombinedDelayLine0 = _ } } _.interactions.sampleCombinedDelayLine0
          (inj (Proxy :: Proxy "sampleCombinedDelayLine0"))
          t2
        LeadSampleDelayLine0 t2 -> handleT2 newPush _ { interactions { leadSampleDelayLine0 = _ } } _.interactions.leadSampleDelayLine0
          (inj (Proxy :: Proxy "leadSampleDelayLine0"))
          t2
        LeadSampleDelayLine1 t2 -> handleT2 newPush _ { interactions { leadSampleDelayLine1 = _ } } _.interactions.leadSampleDelayLine1
          (inj (Proxy :: Proxy "leadSampleDelayLine1"))
          t2
        LeadSampleDelayLine2 t2 -> handleT2 newPush _ { interactions { leadSampleDelayLine2 = _ } } _.interactions.leadSampleDelayLine2
          (inj (Proxy :: Proxy "leadSampleDelayLine2"))
          t2
        LoopingBufferGainDJ t2 -> handleT2 newPush _ { interactions { loopingBufferGainDJ = _ } } _.interactions.loopingBufferGainDJ
          (inj (Proxy :: Proxy "loopingBufferGainDJ"))
          t2
        LoopingBuffer0 t2 -> handleT2 newPush _ { interactions { loopingBuffer0 = _ } } _.interactions.loopingBuffer0
          (inj (Proxy :: Proxy "loopingBuffer0"))
          t2
        LoopingBuffer1 t2 -> handleT2 newPush _ { interactions { loopingBuffer1 = _ } } _.interactions.loopingBuffer1
          (inj (Proxy :: Proxy "loopingBuffer1"))
          t2
        LoopingBuffer2 t2 -> handleT2 newPush _ { interactions { loopingBuffer2 = _ } } _.interactions.loopingBuffer2
          (inj (Proxy :: Proxy "loopingBuffer2"))
          t2
        LoopingBuffer3 t2 -> handleT2 newPush _ { interactions { loopingBuffer3 = _ } } _.interactions.loopingBuffer3
          (inj (Proxy :: Proxy "loopingBuffer3"))
          t2
        LoopingBuffer4 t2 -> handleT2 newPush _ { interactions { loopingBuffer4 = _ } } _.interactions.loopingBuffer4
          (inj (Proxy :: Proxy "loopingBuffer4"))
          t2
        RadicalFlip t2 -> handleT2 newPush _ { interactions { radicalFlip = _ } } _.interactions.radicalFlip
          (inj (Proxy :: Proxy "radicalFlip"))
          t2
        GlobalDelay t2 -> handleT2 newPush _ { interactions { globalDelay = _ } } _.interactions.globalDelay
          (inj (Proxy :: Proxy "globalDelay"))
          t2
        ----
        TriggerLead ud -> do
          H.modify_ _ { interactions { triggerLead = ud } }
          when ud do
            H.liftEffect
              $ newPush
              $ wrap
              $ (inj (Proxy :: Proxy "triggerLead") Bang)
        SampleOneShot ud -> do
          H.modify_ _ { interactions { sampleOneShot = ud } }
          when ud do
            H.liftEffect
              $ newPush
              $ wrap
              $ (inj (Proxy :: Proxy "sampleOneShot") Bang)
        UncontrollableSingleton ud -> do
          H.modify_ _ { interactions { echoingUncontrollableSingleton = ud } }
          when ud do
            H.liftEffect
              $ newPush
              $ wrap
              $ (inj (Proxy :: Proxy "echoingUncontrollableSingleton") Bang)
        ------
        EnvelopeLead t3 -> handleT3 newPush _ { interactions { envelopeLead = _ } } _.interactions.envelopeLead
          (inj (Proxy :: Proxy "envelopeLead"))
          t3
        OctaveLead t3 -> handleT3 newPush _ { interactions { octaveLead = _ } } _.interactions.octaveLead
          (inj (Proxy :: Proxy "octaveLead"))
          t3
        SampleRateChange t3 -> handleT3 newPush _ { interactions { sampleRateChange = _ } } _.interactions.sampleRateChange
          (inj (Proxy :: Proxy "sampleRateChange"))
          t3
        ------
        DetunePad t4 -> handleT4 newPush _ { interactions { detunePad = _ } } _.interactions.detunePad
          (inj (Proxy :: Proxy "detunePad"))
          t4
        ------
        FilterBankChooserPad t5 -> handleT5 newPush _ { interactions { filterBankChooserPad = _ } } _.interactions.filterBankChooserPad
          (inj (Proxy :: Proxy "filterBankChooserPad"))
          t5
        DroneChooser t5 -> handleT5 newPush _ { interactions { droneChooser = _ } } _.interactions.droneChooser
          (inj (Proxy :: Proxy "droneChooser"))
          t5
        DroneRhythmicLoopingPiecewiseFunction t5 -> handleT5 newPush _ { interactions { droneRhythmicLoopingPiecewiseFunction = _ } } _.interactions.droneRhythmicLoopingPiecewiseFunction
          (inj (Proxy :: Proxy "droneRhythmicLoopingPiecewiseFunction"))
          t5
        SynthForLead t5 -> handleT5 newPush _ { interactions { synthForLead = _ } } _.interactions.synthForLead
          (inj (Proxy :: Proxy "synthForLead"))
          t5
        TriggerPad pa -> case pa of
          PadUp -> H.modify_ _ { interactions { triggerPadUp = true } }
          PadDown -> H.modify_ _ { interactions { triggerPadUp = false } }
        Drone pa -> case pa of
          PadUp -> H.modify_ _ { interactions { droneUp = true } }
          PadDown -> H.modify_ _ { interactions { droneUp = false } }
  ---
  DoPadStuff -> do
    s <- H.get
    let droneV = min 1.0 $ max 0.0 $ s.interactions.drone + (if s.interactions.droneUp then 0.01 else -0.01)
    let triggerPadV = min 1.0 $ max 0.0 $ s.interactions.triggerPad + (if s.interactions.triggerPadUp then 0.01 else -0.01)
    H.modify_ _
      { interactions
          { drone = droneV
          , triggerPad = triggerPadV
          }
      }
    H.liftEffect
      $ usingHT Here localEvent.push
      $ wrap
      $ inj (Proxy :: Proxy "triggerPad")
          { v: wrap triggerPadV
          , ud: s.interactions.triggerPadUp
          }
    H.liftEffect
      $ usingHT Here localEvent.push
      $ wrap
      $ inj (Proxy :: Proxy "drone")
          { v: wrap droneV
          , ud: s.interactions.droneUp
          }
  MouseMove (mmx /\ mmy) -> H.liftEffect do
    publish pubnub
      $ PubNubMessage
      $ inj (Proxy :: Proxy "ui")
      $ UIEvent
      $ inj (Proxy :: Proxy "mouse")
      $ { x: mmx, y: mmy }
  MoveRemoteMouse pmxy -> H.modify_ \s -> s
    { mice = Object.alter
        ( const $ Just
            { timetoken: pmxy.timetoken
            , x: pmxy.x
            , y: pmxy.y
            }
        )
        pmxy.publisher
        s.mice
    }
  StartAudio -> do
    handleAction remoteEvent localEvent pubnub buffers StopAudio
    audioCtx <- H.liftEffect context
    ffiAudio <- H.liftEffect $ makeFFIAudioSnapshot audioCtx
    periodic <- H.liftEffect $ makePeriodicWave audioCtx (0.3 +> 0.05 +> 0.1 +> 0.05 +> empty) (0.1 +> 0.2 +> 0.03 +> 0.6 +> empty)
    waveshaperArray <- H.liftEffect $ makeFloatArray dc
    unsubscribe0 <-
      H.liftEffect
        $ subscribe
            ( runNoLoop
                ( Trigger <$>
                    ( inj (Proxy :: Proxy "event") <$>
                        ( filterMap
                            ( unwrap
                                >>> _.message
                                >>> unwrap
                                >>> prj (Proxy :: Proxy "music")
                            )
                            remoteEvent
                        )
                        <|>
                          inj (Proxy :: Proxy "event") <$> (map snd localEvent.event)
                        <|>
                          (pure $ inj (Proxy :: Proxy "thunk") unit)
                    )
                )
                (pure { buffers, periodic, waveshaperArray })
                {}
                ffiAudio
                (piece initialAcc setup oracle)
            )
            (\(o :: TriggeredRun Res ()) -> Log.info $ show o)
    { emitter, listener } <- H.liftEffect HS.create
    unsubscribe1 <- H.liftEffect $
      subscribe remoteEvent
        ( \(PubNubEvent { timetoken, publisher, message }) -> (unwrap message) # match
            { ui: unwrap >>> match
                { mouse: \mxy -> HS.notify listener (MoveRemoteMouse { publisher, timetoken, x: mxy.x, y: mxy.y })
                , click: \_ -> pure unit
                }
            , music: unwrap >>> onMatch
                { gainLFO0Pad: uzto
                    >>> SliderRemoteMove
                    >>> GainLFO0Pad
                    >>> MusicalAction There
                    >>> HS.notify listener
                , gainLFO1Pad: uzto
                    >>> SliderRemoteMove
                    >>> GainLFO1Pad
                    >>> MusicalAction There
                    >>> HS.notify listener
                , waveshaperPad: uzto
                    >>> SliderRemoteMove
                    >>> WaveshaperPad
                    >>> MusicalAction There
                    >>> HS.notify listener
                , pitchLead: ezto >>> uzto
                    >>> SliderRemoteMove
                    >>> PitchLead
                    >>> MusicalAction There
                    >>> HS.notify listener
                , leadDelayGainCarousel: uzto
                    >>> SliderRemoteMove
                    >>> LeadDelayGainCarousel
                    >>> MusicalAction There
                    >>> HS.notify listener
                , nPitchesPlayedLead: ezto >>> uzto
                    >>> SliderRemoteMove
                    >>> NPitchesPlayedLead
                    >>> MusicalAction There
                    >>> HS.notify listener
                , droneLowpass0Q: uzto
                    >>> SliderRemoteMove
                    >>> DroneLowpass0Q
                    >>> MusicalAction There
                    >>> HS.notify listener
                , droneBandpass0Q: uzto
                    >>> SliderRemoteMove
                    >>> DroneBandpass0Q
                    >>> MusicalAction There
                    >>> HS.notify listener
                , droneBandpass0LFO: uzto
                    >>> SliderRemoteMove
                    >>> DroneBandpass0LFO
                    >>> MusicalAction There
                    >>> HS.notify listener
                , droneBandpass1Q: uzto
                    >>> SliderRemoteMove
                    >>> DroneBandpass1Q
                    >>> MusicalAction There
                    >>> HS.notify listener
                , droneBandpass1LFO: uzto
                    >>> SliderRemoteMove
                    >>> DroneBandpass1LFO
                    >>> MusicalAction There
                    >>> HS.notify listener
                , droneHighpass0Q: uzto
                    >>> SliderRemoteMove
                    >>> DroneHighpass0Q
                    >>> MusicalAction There
                    >>> HS.notify listener
                , droneHighpass0LFO: uzto
                    >>> SliderRemoteMove
                    >>> DroneHighpass0LFO
                    >>> MusicalAction There
                    >>> HS.notify listener
                , droneActivationEnergyThreshold: uzto
                    >>> SliderRemoteMove
                    >>> DroneActivationEnergyThreshold
                    >>> MusicalAction There
                    >>> HS.notify listener
                , droneDecay: uzto
                    >>> SliderRemoteMove
                    >>> DroneDecay
                    >>> MusicalAction There
                    >>> HS.notify listener
                , sampleChooser: ezto >>> uzto
                    >>> SliderRemoteMove
                    >>> SampleChooser
                    >>> MusicalAction There
                    >>> HS.notify listener
                , sampleDelayGainCarousel: uzto
                    >>> SliderRemoteMove
                    >>> SampleDelayGainCarousel
                    >>> MusicalAction There
                    >>> HS.notify listener
                , loopingBufferStartEndConstriction: uzto
                    >>> SliderRemoteMove
                    >>> LoopingBufferStartEndConstriction
                    >>> MusicalAction There
                    >>> HS.notify listener
                , greatAndMightyPan: uzto
                    >>> SliderRemoteMove
                    >>> GreatAndMightyPan
                    >>> MusicalAction There
                    >>> HS.notify listener
                , distantBellsFader: uzto
                    >>> SliderRemoteMove
                    >>> DistantBellsFader
                    >>> MusicalAction There
                    >>> HS.notify listener
                -----
                , togglePadOsc0: et2
                    >>> TogglePadOsc0
                    >>> MusicalAction There
                    >>> HS.notify listener
                , togglePadOsc1: et2
                    >>> TogglePadOsc1
                    >>> MusicalAction There
                    >>> HS.notify listener
                , togglePadOsc2: et2
                    >>> TogglePadOsc2
                    >>> MusicalAction There
                    >>> HS.notify listener
                , togglePadOsc3: et2
                    >>> TogglePadOsc3
                    >>> MusicalAction There
                    >>> HS.notify listener
                , togglePadOsc4: et2
                    >>> TogglePadOsc4
                    >>> MusicalAction There
                    >>> HS.notify listener
                , leadDelayLine0: et2
                    >>> LeadDelayLine0
                    >>> MusicalAction There
                    >>> HS.notify listener
                , leadDelayLine1: et2
                    >>> LeadDelayLine1
                    >>> MusicalAction There
                    >>> HS.notify listener
                , leadDelayLine2: et2
                    >>> LeadDelayLine2
                    >>> MusicalAction There
                    >>> HS.notify listener
                , leadCombinedDelay0: et2
                    >>> LeadCombinedDelay0
                    >>> MusicalAction There
                    >>> HS.notify listener
                , droneFlange: et2
                    >>> DroneFlange
                    >>> MusicalAction There
                    >>> HS.notify listener
                , sampleReverse: et2
                    >>> SampleReverse
                    >>> MusicalAction There
                    >>> HS.notify listener
                , sampleChorusEffect: et2
                    >>> SampleChorusEffect
                    >>> MusicalAction There
                    >>> HS.notify listener
                , sampleDelayLine0: et2
                    >>> SampleDelayLine0
                    >>> MusicalAction There
                    >>> HS.notify listener
                , sampleDelayLine1: et2
                    >>> SampleDelayLine1
                    >>> MusicalAction There
                    >>> HS.notify listener
                , sampleDelayLine2: et2
                    >>> SampleDelayLine2
                    >>> MusicalAction There
                    >>> HS.notify listener
                , sampleCombinedDelayLine0: et2
                    >>> SampleCombinedDelayLine0
                    >>> MusicalAction There
                    >>> HS.notify listener
                , leadSampleDelayLine0: et2
                    >>> LeadSampleDelayLine0
                    >>> MusicalAction There
                    >>> HS.notify listener
                , leadSampleDelayLine1: et2
                    >>> LeadSampleDelayLine1
                    >>> MusicalAction There
                    >>> HS.notify listener
                , leadSampleDelayLine2: et2
                    >>> LeadSampleDelayLine2
                    >>> MusicalAction There
                    >>> HS.notify listener
                , loopingBufferGainDJ: et2
                    >>> LoopingBufferGainDJ
                    >>> MusicalAction There
                    >>> HS.notify listener
                , loopingBuffer0: et2
                    >>> LoopingBuffer0
                    >>> MusicalAction There
                    >>> HS.notify listener
                , loopingBuffer1: et2
                    >>> LoopingBuffer1
                    >>> MusicalAction There
                    >>> HS.notify listener
                , loopingBuffer2: et2
                    >>> LoopingBuffer2
                    >>> MusicalAction There
                    >>> HS.notify listener
                , loopingBuffer3: et2
                    >>> LoopingBuffer3
                    >>> MusicalAction There
                    >>> HS.notify listener
                , loopingBuffer4: et2
                    >>> LoopingBuffer4
                    >>> MusicalAction There
                    >>> HS.notify listener
                , radicalFlip: et2
                    >>> RadicalFlip
                    >>> MusicalAction There
                    >>> HS.notify listener
                , globalDelay: et2
                    >>> GlobalDelay
                    >>> MusicalAction There
                    >>> HS.notify listener
                --
                -- ignore remote events
                -- we make pad triggers entirely local
                , triggerPad: \(_ :: PadT) -> pure unit
                , drone: \(_ :: PadT) -> pure unit
                ---
                -- ignore triggering events
                -- this way, we only get sound if we want it
                -- perhaps allow in future, but then we'd need to
                -- create flicker as we don't want to track mouse up
                -- and mouse down from remote
                , triggerLead: \(_ :: Bang) -> pure unit
                , sampleOneShot: \(_ :: Bang) -> pure unit
                , echoingUncontrollableSingleton: \(_ :: Bang) -> pure unit
                --
                , octaveLead: et3
                    >>> OctaveLead
                    >>> MusicalAction There
                    >>> HS.notify listener
                , envelopeLead: et3
                    >>> EnvelopeLead
                    >>> MusicalAction There
                    >>> HS.notify listener
                , sampleRateChange: et3
                    >>> SampleRateChange
                    >>> MusicalAction There
                    >>> HS.notify listener
                ----
                , detunePad: et4
                    >>> DetunePad
                    >>> MusicalAction There
                    >>> HS.notify listener
                ---
                , filterBankChooserPad: et5
                    >>> FilterBankChooserPad
                    >>> MusicalAction There
                    >>> HS.notify listener
                , droneChooser: et5
                    >>> DroneChooser
                    >>> MusicalAction There
                    >>> HS.notify listener
                , droneRhythmicLoopingPiecewiseFunction: et5
                    >>> DroneRhythmicLoopingPiecewiseFunction
                    >>> MusicalAction There
                    >>> HS.notify listener
                , synthForLead: et5
                    >>> SynthForLead
                    >>> MusicalAction There
                    >>> HS.notify listener
                }
                (default (pure unit))
            }
        )
    -- don't send pad interactions over the wire
    -- let that be local
    unsubscribe2 <- H.liftEffect $ subscribe localEvent.event \e ->
      onMatch
        { triggerPad: \_ -> pure unit
        , drone: \_ -> pure unit
        , triggerLead: \_ -> pure unit
        , sampleOneShot: \_ -> pure unit
        , echoingUncontrollableSingleton: \_ -> pure unit
        }
        ( default $ case fst e of
            Here -> publish pubnub
              $ PubNubMessage
              $ inj (Proxy :: Proxy "music") (snd e)
            There -> pure unit
        )
        (unwrap (snd e))
    unsubscribe3 <- H.liftEffect $ subscribe (interval 200) \_ ->
      H.liftEffect $ HS.notify listener DoPadStuff
    subscription <- H.subscribe emitter
    H.modify_ _
      { unsubscribe = unsubscribe0
          *> unsubscribe1
          *> unsubscribe2
          *> unsubscribe3
      , unsubscribeHalogen = Just subscription
      , audioCtx = Just audioCtx
      }
  StopAudio -> do
    { unsubscribe, unsubscribeHalogen, audioCtx } <- H.get
    H.liftEffect unsubscribe
    for_ unsubscribeHalogen H.unsubscribe
    H.liftEffect do
      for_ audioCtx close
    H.modify_ _ { unsubscribe = pure unit, audioCtx = Nothing }
