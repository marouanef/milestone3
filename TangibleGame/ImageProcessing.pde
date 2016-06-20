class ImageProcessing extends PApplet {  //<>//
  TwoDThreeD         computations;
  QuadGraph          graph         = new QuadGraph();
  PVector            rotations;
  boolean            ready         = false;
  boolean            continueExec  = false;
  int                imgWidth;
  int                imgHeight;
  int                phiDim;
  int                rDim;
  float[]            tabSin;
  float[]            tabCos;
  int[]              accumulator;
  ArrayList<PVector> lines;
  ArrayList<PVector> bestLines;
  ArrayList<PVector> intersections;

  public void settings() {
    if (videoMode) {
      size((int) ((2 + 0.5) * cam.width), cam.height);
    } else {
      size((int) ((2 + 0.5) * img.width), img.height);
    }
  }

  public void setup() {
    graph  = new QuadGraph();
    phiDim = (int) (Math.PI / discretizationStepsPhi);
    rDim = 0;
    tabSin = new float[phiDim + 2];
    tabCos = new float[phiDim + 2];
    computeTables();
    lines  = new ArrayList<PVector>();
    intersections = new ArrayList<PVector>();
    if (!videoMode) {
      noLoop();
    }
  }

  public void draw() {
    if (videoMode) {
      if (cam.available()) {
        cam.read();  
        img = cam.get();
        continueExec = true;
      }
    }
    if (!videoMode || continueExec || !ready) {
      computations = new TwoDThreeD(img.width, img.height);
      int counter = 0;
      float brightnessMean = -1;
      int hueMean = 0;
      for (int i = 0; i < img.pixels.length; i++) {
        if (hue(img.pixels[i]) > 110 && hue(img.pixels[i]) < 136) {
          hueMean += hue(img.pixels[i]);
          brightnessMean += brightness(img.pixels[i]);
          counter++;
        }
      }

      hueMean /= counter;
      brightnessMean /= counter;
      PImage img1;
      if (!videoMode) {
        img1 = hueFilter(hueMean - 15, hueMean + 10, img);
      } else {
        img1 = hueFilter(65, 125, img);
      }
      PImage img2 = saturationFilter(100, 255, img1);
      PImage img3 = gauss(100.f, img2);
      PImage img4 = brightnessFilter(10, brightnessMean + 35, img3);
      PImage img5 = sobel(img4);
      compute(img5);
      if (videoMode) {
        updateLines(6);
      } else {
        updateLines(4);
      }

      updateIntersections();
      image(img, 0, 0);
      drawLines();
      drawIntersections();
      drawAccumulator();
      image(img5, img.width, 0);
      if (intersections.size() == 4) {
        rotations = computations.get3DRotations(intersections);
      }
      ready = true;
    }
  }

  float[][] gauss           = { { 9, 12, 9 }, 
    { 12, 15, 12 }, 
    { 9, 12, 9 }};

  PImage hueFilter(int lowerBound, int upperBound, PImage img) {
    PImage result = createImage(img.width, img.height, RGB); // create a new, initially transparent, ’result’ image
    for (int i = 0; i < img.pixels.length; i++) {
      if (hue(img.pixels[i]) > lowerBound && hue(img.pixels[i]) < upperBound) {
        result.pixels[i] = img.pixels[i];
      } else {
        result.pixels[i] = color(0);
      }
    }
    return result;
  }

  PImage saturationFilter(int lowerBound, int upperBound, PImage img) {
    PImage result = createImage(img.width, img.height, RGB); // create a new, initially transparent, ’result’ image
    for (int i = 0; i < img.pixels.length; i++) {
      if (saturation(img.pixels[i]) > lowerBound && saturation(img.pixels[i]) < upperBound) {
        result.pixels[i] = img.pixels[i];
      } else {
        result.pixels[i] = color(0);
      }
    }
    return result;
  }

  PImage brightnessFilter(float lowerBound, float upperBound, PImage img) {
    PImage result = createImage(img.width, img.height, RGB); // create a new, initially transparent, ’result’ image
    for (int i = 0; i < img.pixels.length; i++) {
      if (brightness(img.pixels[i]) < upperBound && brightness(img.pixels[i]) > lowerBound) {
        result.pixels[i] = color(255);
      } else {
        result.pixels[i] = color(0);
      }
    }
    return result;
  }

  PImage convolute(float[][] kernel, float weight, PImage img) {
    PImage result = createImage(img.width, img.height, ALPHA);

    for (int x = 1; x < img.width - 1; x++) {
      for (int y = 1; y < img.height - 1; y++) {
        int brightness = 0;
        for (int i = 0; i < kernel.length; i++) {
          for (int j = 0; j < kernel.length; j++) {
            int pos = ((x + i) - kernel.length/2) + ((y + j) - kernel.length/2) * img.width;
            brightness += brightness(img.pixels[pos]) * kernel[i][j];
          }
        }
        brightness /= weight;
        result.pixels[x + y * img.width] = color(brightness);
      }
    }

    return result;
  }

  PImage gauss(float weight, PImage img) {
    return convolute(gauss, weight, img);
  }

  PImage sobel(PImage img) {
    float[][] hKernel = { { 0, 1, 0 }, 
      { 0, 0, 0 }, 
      { 0, -1, 0 } };

    float[][] vKernel = { { 0, 0, 0 }, 
      { 1, 0, -1 }, 
      { 0, 0, 0 } };

    PImage result = createImage(img.width, img.height, ALPHA);
    // clear the image
    for (int i = 0; i < img.width * img.height; i++) {
      result.pixels[i] = color(0);
    }

    float max=0;
    float[] buffer = new float[img.width * img.height];


    for (int x = 1; x < img.width - 1; x++) {
      for (int y = 1; y < img.height - 1; y++) {
        int sum_h = 0;
        int sum_v = 0;
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            int pos = ((x + i) - 1) + ((y + j) - 1) * img.width;
            sum_h += brightness(img.pixels[pos]) * hKernel[i][j];
            sum_v += brightness(img.pixels[pos]) * vKernel[i][j];
          }
        }
        float sum = sqrt((sum_h * sum_h) + (sum_v * sum_v));
        if (sum > max) {
          max = sum;
        }
        buffer[x + y * img.width] = sum;
      }
    }

    for (int y = 2; y < img.height - 2; y++) { // Skip top and bottom edges
      for (int x = 2; x < img.width - 2; x++) { // Skip left and right
        if (buffer[y * img.width + x] > (int)(max * 0.5f)) { // 30% of the max
          result.pixels[y * img.width + x] = color(255);
        } else {
          result.pixels[y * img.width + x] = color(0);
        }
      }
    }
    return result;
  }
  void computeTables() {
    float ang = 0;
    float inverseR = 1.f / discretizationStepsR;
    for (int accPhi = 0; accPhi <= phiDim + 1; ang += discretizationStepsPhi, accPhi++) {
      // we can also pre-multiply by (1/discretizationStepsR) since we need it in the Hough loop
      tabSin[accPhi] = (float) (Math.sin(ang) * inverseR);
      tabCos[accPhi] = (float) (Math.cos(ang) * inverseR);
    }
  }

  void compute(PImage edgeImg) {
    imgWidth = edgeImg.width;
    imgHeight = edgeImg.height;
    rDim = (int) (((imgWidth + imgHeight) * 2 + 1) / discretizationStepsR);
    int[] accumulator = new int[(phiDim + 2) * (rDim + 2)];
    for (int y = 0; y < imgHeight; y++) {
      for (int x = 0; x < imgWidth; x++) {
        if (brightness(edgeImg.pixels[y * imgWidth + x]) != 0) {
          for (int phi = 0; phi <= phiDim + 1; phi++) {
            int r = (int) (x * tabCos[phi] + y * tabSin[phi]);
            r += (rDim - 1) / 2 ;
            accumulator[phi * rDim + r] += 1;
          }
        }
      }
    }
    this.accumulator = accumulator;
  }

  void updateLines(int nLines) {
    lines = new ArrayList<PVector>();
    ArrayList<Integer> bestCandidates = new ArrayList<Integer>();
    // size of the region we search for a local maximum
    int neighbourhood;
    // only search around lines with more that this amount of votes
    // (to be adapted to your image)
    int minVotes;
    if(!videoMode) {
      minVotes = 100;
      neighbourhood = 10;
    } else {
      minVotes = 0;
      neighbourhood = 30;
    }
    for (int accR = 0; accR < rDim; accR++) {
      for (int accPhi = 0; accPhi < phiDim; accPhi++) {
        // compute current index in the accumulator
        int idx = (accPhi + 1) * (rDim + 2) + accR + 1;
        if (accumulator[idx] > minVotes) {
          boolean bestCandidate=true;
          // iterate over the neighbourhood
          for (int dPhi=-neighbourhood/2; dPhi < neighbourhood/2+1; dPhi++) {
            // check we are not outside the image
            if ( accPhi+dPhi < 0 || accPhi+dPhi >= phiDim) continue;
            for (int dR=-neighbourhood/2; dR < neighbourhood/2 +1; dR++) {
              // check we are not outside the image
              if (accR+dR < 0 || accR+dR >= rDim) continue;
              int neighbourIdx = (accPhi + dPhi + 1) * (rDim + 2) + accR + dR + 1;
              if (accumulator[idx] < accumulator[neighbourIdx]) {
                // the current idx is not a local maximum!
                bestCandidate=false;
                break;
              }
            }
            if (!bestCandidate) break;
          }
          if (bestCandidate) {
            // the current idx *is* a local maximum
            bestCandidates.add(idx);
          }
        }
      }
    }

    Collections.sort(bestCandidates, new HoughComparator(accumulator));
    for (int j = 0; j < min(bestCandidates.size(), nLines); j++) {
      int idx = bestCandidates.get(j);
      int accPhi = (int) (idx / rDim);
      int accR = idx - (accPhi * rDim);
      float r = (accR - ((rDim - 1) * 0.5f));
      r *= discretizationStepsR;
      float phi = accPhi * discretizationStepsPhi;
      lines.add(new PVector(r, phi));
    }
  }

  PVector intersection(PVector v1, PVector v2) {
    float d = cos(v2.y) * sin(v1.y) - cos(v1.y) * sin(v2.y); 
    float x = v2.x * sin(v1.y) - v1.x * sin(v2.y);
    x /= d;
    float y = v1.x * cos(v2.y) - v2.x * cos(v1.y);
    y /= d;
    return new PVector(x, y);
  }

  void updateIntersections() {
    bestLines = new ArrayList<PVector>();
    intersections = new ArrayList<PVector>();
    graph = new QuadGraph();
    graph.build(lines, img.width, img.height);

    List<int[]> quads = graph.findCycles();

    for (int[] quad : quads) {
      PVector l1 = lines.get(quad[0]);
      PVector l2 = lines.get(quad[1]);
      PVector l3 = lines.get(quad[2]);
      PVector l4 = lines.get(quad[3]);
      PVector[] quadLines = {l1, l2, l3, l4};

      PVector c12 = intersection(l1, l2);
      PVector c23 = intersection(l2, l3);
      PVector c34 = intersection(l3, l4);
      PVector c41 = intersection(l4, l1);
      PVector[] vectorQuad = {c12, c23, c34, c41};

      if (graph.isConvex(c12, c23, c34, c41) &&
        graph.validArea(c12, c23, c34, c41, img.width * img.height, 0.1 *( img.width * img.height)) &&
        graph.nonFlatQuad(c12, c23, c34, c41)
        ) { 
        List<PVector> toTest = graph.sortCorners(Arrays.asList(vectorQuad));
        if (graph.squareTest1(toTest.get(0), toTest.get(1), toTest.get(2), toTest.get(3)) || graph.squareTest2(toTest.get(0), toTest.get(1), toTest.get(2), toTest.get(3))) {
          intersections = new ArrayList<PVector>(toTest);
          bestLines = new ArrayList<PVector>(Arrays.asList(quadLines));
        }
      }
    }
  }

  void drawAccumulator() {
    PImage houghImg = createImage(rDim + 2, phiDim + 2, ALPHA);
    for (int i = 0; i < accumulator.length; i++) {
      houghImg.pixels[i] = color(min(255, accumulator[i]));
    }
    houghImg.resize(img.width / 2, img.height);
    houghImg.updatePixels();
    imageProc.image(houghImg, 2 * img.width, 0);
  }

  void drawLines() {
    for (PVector line : bestLines) {
      int x0 = 0;
      int y0 = (int) (line.x / sin(line.y));
      int x1 = (int) (line.x / cos(line.y));
      int y1 = 0;
      int x2 = imgWidth;
      int y2 = (int) (-cos(line.y) / sin(line.y) * x2 + line.x / sin(line.y));
      int y3 = imgHeight;
      int x3 = (int) (-(y3 - line.x / sin(line.y)) * (sin(line.y) / cos(line.y)));
      // Finally, plot the lines
      imageProc.stroke(204, 102, 0);
      if (y0 > 0) {
        if (x1 > 0)
          imageProc.line(x0, y0, x1, y1);
        else if (y2 > 0)
          imageProc.line(x0, y0, x2, y2);
        else
          imageProc.line(x0, y0, x3, y3);
      } else {
        if (x1 > 0) {
          if (y2 > 0)
            imageProc.line(x1, y1, x2, y2);
          else
            imageProc.line(x1, y1, x3, y3);
        } else
          imageProc.line(x2, y2, x3, y3);
      }
    }
  }

  void drawIntersections() {
    imageProc.fill(color(255));

    for (PVector inter : intersections) {
      imageProc.ellipse(inter.x, inter.y, 10, 10);
    }
  }
}

class HoughComparator implements java.util.Comparator<Integer> {
  int[] accumulator;
  public HoughComparator(int[] accumulator) {
    this.accumulator = accumulator;
  }
  @Override
    public int compare(Integer l1, Integer l2) {
    if (accumulator[l1] > accumulator[l2]
      || (accumulator[l1] == accumulator[l2] && l1 < l2)) return -1;
    return 1;
  }
}