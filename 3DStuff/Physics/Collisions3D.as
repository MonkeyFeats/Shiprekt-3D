#include "Vec3f.as";
#include "SAT_Shapes.as";

class ICollisionCallback
{
    public:
    virtual bool onCollision(const ISceneNodeAnimatorCollisionResponse& animator) = 0;
};

class ISceneNodeAnimatorCollisionResponse
{
    ~ISceneNodeAnimatorCollisionResponse() {}

    bool isFalling() const = 0;

    void setEllipsoidRadius(const core::vector3df& radius) = 0;

    core::vector3df getEllipsoidRadius() const = 0;


    void setGravity(const core::vector3df& gravity) = 0;

    core::vector3df getGravity() const = 0;


    void jump(f32 jumpSpeed) = 0;

    void setAnimateTarget ( bool enable ) = 0;
    bool getAnimateTarget () const = 0;


    void setEllipsoidTranslation(const core::vector3df &translation) = 0;


    core::vector3df getEllipsoidTranslation() const = 0;


    void setWorld(ITriangleSelector* newWorld) = 0;

    ITriangleSelector* getWorld() const = 0;


    void setTargetNode(ISceneNode * node) = 0;


    ISceneNode* getTargetNode(void) const = 0;

    bool collisionOccurred() const = 0;

    const core::vector3df & getCollisionPoint() const = 0;

    const core::triangle3df & getCollisionTriangle() const = 0;


    const core::vector3df & getCollisionResultPosition(void) const = 0;

    ISceneNode* getCollisionNode(void) const = 0;


    void setCollisionCallback(ICollisionCallback* callback) = 0;

};