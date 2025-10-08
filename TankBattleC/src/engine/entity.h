#ifndef _ENTITY_H_
#define _ENTITY_H_

#include <glm/glm.hpp>

class Entity {
  protected:
    int id;
    glm::vec2 position;
  public:

    int getId() const;
    glm::vec2 getPosition() const;
    
};

#endif
