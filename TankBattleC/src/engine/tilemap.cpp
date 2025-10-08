#include "tilemap.h"
#include "renderer2D.h"
#include <glm/glm.hpp>
#include <fstream>
#include <iostream>
#include <sstream>
#include <cmath>

bool Tilemap::loadMapFromFile(const std::string& filename) {
  std::ifstream file(filename, std::ios::binary);
  std::string line;

  if(!file.is_open()) {
    return false;
  }

  // read the size of the map
  std::getline(file, line);
  std::istringstream ss(line);

  ss >> width;
  ss >> height;
  int v;

  tiles = new uint8_t[width*height];
  int c = 0;

  for(int i=0; i<height; i++) {
    std::getline(file, line);
    std::istringstream strline(line);
    for(int j=0; j<width; j++) {
      strline >> v;
      tiles[c++] = static_cast<uint8_t>(v);
    }
  }
  file.close(); 
  return true;
}

void Tilemap::setSolid(int n, const uint8_t* indices) {
  for (auto i = 0; i < n; i++) {
    solidMap[indices[i]] = true;
  }
}

void Tilemap::draw(Renderer2D& renderer, const glm::mat4& vp) const {
  renderer.begin(vp);
  for (int y=0; y < height; ++y) {
    for (int x = 0; x < width; ++x) {
      if(isSolid(x,y)) {
        glm::vec2 pos = { x*tileSize + tileSize*0.5f, y*tileSize + tileSize*0.5f };
        renderer.drawQuad(pos, {tileSize, tileSize}, 0.0f, {0.20f, 0.24f, 0.28f, 1.0f});
      }
    }
  }
  renderer.end();
}

Tilemap::~Tilemap() {
  if (tiles != nullptr) {
    delete[] tiles;
    tiles = nullptr;
  }
}

