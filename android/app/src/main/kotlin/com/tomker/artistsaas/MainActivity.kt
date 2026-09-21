package com.tomker.artistsaas

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.android.FlutterActivity

// `AudioServiceActivity` est requis par `just_audio_background` : il installe
// le pont entre le moteur Flutter et le service natif de lecture en
// arrière-plan (notification média, contrôles casque, écran verrouillé).
class MainActivity : AudioServiceActivity()
