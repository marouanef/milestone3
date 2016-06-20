class Setter {
  Setter() {
  }

  void firstImageProcessingSetup() {
    i = 0;
    videoAnglesX = new ArrayList<Float>();
    videoAnglesZ = new ArrayList<Float>();
    for (int i = 0; i < weight; i++) {
      videoAnglesX.add(0f);
      videoAnglesZ.add(0f);
    }

    cam.loop();
    cam.read();
    if (!videoMode) {
      img = loadImage(imageName);
    } 
    imageProc = new ImageProcessing();
    String []args = {"Image processing window"};
    PApplet.runSketch(args, imageProc);
  }

  void setSketch() {
    camera();
    ambientLight(red(ambientLightColor), green(ambientLightColor), blue(ambientLightColor));
    background(255);
    directionalLight(red(directionalLightColor), green(directionalLightColor), blue(directionalLightColor), 1, 1, -1);
  }

  void setSpeed() {
    if (speedValue <= speedValueLowerLimit) {
      speedValue = speedValueLowerLimit;
    } else if (speedValue >= speedValueUpperLimit) {
      speedValue = speedValueUpperLimit;
    }
  }

  void setAngleValues() {
    if (angleZ < -limitAngle) {
      angleZ = -limitAngle;
    } else if (angleZ > limitAngle) {
      angleZ = limitAngle;
    } 
    if (angleX < -limitAngle) {
      angleX = -limitAngle;
    } else if (angleX > limitAngle) {
      angleX = limitAngle;
    }
  }

  void imageProcessing() {
    if (imageProcessing) {
      if (videoMode) {
        if (imageProc.ready) {
          PVector rot = imageProc.rotations;
          if (rot != null) {
            angleX = 0;
            angleZ = 0;
            imageProc.ready = false;
            int oldI = i;
            i = (i + 1) % weight;
            if (abs(videoAnglesX.get(oldI) - rot.x) < PI / 3 || rot.x == 0) {
              videoAnglesX.set(i, rot.x);
            } else {
              videoAnglesX.set(i, videoAnglesX.get(oldI));
            }
            if (abs(videoAnglesZ.get(oldI)) - rot.y < PI / 3 || rot.y == 0) {
              videoAnglesZ.set(i, rot.y);
            } else {
              videoAnglesZ.set(i, videoAnglesZ.get(oldI));
            }
            for (int j = 0; j < weight; j++) {
              angleX += videoAnglesX.get(j);
              angleZ -= videoAnglesZ.get(j);
            }
            angleX /= weight;
            angleZ /= weight;
          }
        }
      } else {
        if (imageProc.ready && !imageProcDone) {
          PVector rot = imageProc.rotations;
          imageProcDone = true;
          angleX = rot.x;
          angleZ = -rot.y;
        }
      }
    }
  }
}