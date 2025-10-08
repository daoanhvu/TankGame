#ifndef _TEXTURE_2D_H_
#define _TEXTURE_2D_H_

#include <string>
#include <glad/gl.h>

class Texture2D {
  unsigned int id = 0;
  int w = 0;
  int h = 0;

  public:
    Texture2D();
    ~Texture2D();

    Texture2D(const Texture2D&) = delete;

    Texture2D& operator=(const Texture2D&) = delete;

    Texture2D(Texture2D&& o) noexcept { 
      id=o.id; 
      w=o.w; 
      h=o.h; 
      o.id=0; 
    }

    Texture2D& operator=(Texture2D&& o) noexcept { 
      if(this!=&o) { 
        if(id) {
          glDeleteTextures(1,&id); 
        }

        id=o.id; 
        w=o.w; 
        h=o.h; 
        o.id=0; 
      } 
      return *this; 
    }


    bool loadFromFile(const std::string& path, bool flipY=true, bool forceRGBA=true);

    void bind(int unit=0) const { 
      glActiveTexture(GL_TEXTURE0+unit); 
      glBindTexture(GL_TEXTURE_2D, id); 
    }

    bool valid() const { return id!=0; }
    int width() const { return w; }
    int height() const { return h; }
};

#endif