#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#include "texture2D.h"
#include <cstdio>

Texture2D::Texture2D() {

}

Texture2D::~Texture2D() {

}

bool Texture2D::loadFromFile(const std::string& path, bool flipY, bool forceRGBA) {
  stbi_set_flip_vertically_on_load(flipY ? 1 : 0);
  int w1,h1,n1;
  unsigned char* data = stbi_load(path.c_str(), &w1, &h1, &n1, forceRGBA ? 4 : 0);
  if(!data) {
    std::fprintf(stderr, "[Texture2D] Failed to load %s\n", path.c_str());
    return false;
  }
  GLenum srcFmt = forceRGBA ? GL_RGBA : (n1==4?GL_RGBA:GL_RGB);

  if(!id) glGenTextures(1, &id);
  glBindTexture(GL_TEXTURE_2D, id);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);


  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w1, h1, 0, srcFmt, GL_UNSIGNED_BYTE, data);
  // No mipmaps by default (pixel art crisp). If you want: glGenerateMipmap(GL_TEXTURE_2D);


  stbi_image_free(data);
  w = w1;
  h = h1; 
  return true;
}