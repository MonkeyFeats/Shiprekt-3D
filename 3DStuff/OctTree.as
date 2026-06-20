#include "Blob3D.as"
#include "AABB.as"
#include "BoundingSphere.as"
#include "Vec3f.as"
#include "ContainmentType.as"

namespace Kag3D
{
    class OcTree
    {
        /// A reference to the parent node is sometimes required. If we are a node and we realize that we no longer have items contained within ourselves,
        /// we need to let our parent know that we're empty so that it can delete us.
        OcTree@ _parent;
        OcTree@ m_root;

        AABB m_region;

        /// This is a list of all objects within the current node of the octree.
        Blob3D[] m_objects;

        /// We want to accrue as many objects in here as possible before we inject them into the tree. This is slightly more cache friendly.
        Blob3D[] m_pendingInsertion;

        /// This is a global list of all the objects within the octree, for easy reference.
        Blob3D[] m_allObjects;
        Blob3D[] m_deadObjects;

        /// These are all of the possible child octants for this node in the tree.
        OcTree[] m_childNode(8); 

        /// This is a bit mask indicating which child nodes are actively being used.
        /// It adds slightly more complexity, but is faster for performance since there is only one comparison instead of 8.
        u8 m_activeNodes = 0;//Byte

        /// The minimum size for enclosing region is a 1x1x1 cube.
        int MIN_SIZE = 1;

        /// this is how many frames we'll wait before deleting an empty tree branch. Note that this is not a constant. The maximum lifespan doubles
        /// every time a node is reused, until it hits a hard coded constant of 64
        int m_maxLifespan = 8;
        int m_curLife = -1; //this is how much time we have left        
        
        bool m_treeReady = false; //the tree has a few objects which need to be inserted before it is complete
        bool m_treeBuilt = false; //there is no pre-existing tree yet.        


        //LineCollection m_BranchCollection;// = LineCollection();
        //SColor m_lineColor = color_white;
        OcTree(){}
        OcTree(AABB region, Blob3D[] objList)
        {
            m_region = region;
            //m_objects = objList;
            m_curLife = -1;
        }

        /// Creates an Octree which is ready for object insertion. The dimensions of the octree will scale to enclose all inserted objects.
        OcTree()
        {
            //m_objects = Blob3D[];
            m_region = AABB(Vec3f(), Vec3f());
            m_curLife = -1;
        }

        /// Creates an octTree with a suggestion for the bounding region containing the items.
        /// <param name="region">The suggested dimensions for the bounding region. 
        /// Note: if items are outside this region, the region will be automatically resized.</param>
        OcTree(AABB region)
        {
            m_region = region;
            //m_objects = Blob3D[] list();
            m_curLife = -1;
        }

        /// Completely removes all content from the octree
        void UnloadContent()
        {
            m_pendingInsertion.clear();
            UnloadHelper(this);
            m_treeBuilt = false;
            m_treeReady = false;
        }

        /// Recursive helper function for removing all nodes in the tree
        /// <param name="root">The root node to start deleting from</param>
        private void UnloadHelper(OcTree root)
        {
            if (root == null) return;

            if (root.m_objects != null) { root.m_objects.clear(); }

            if (m_region != null)
            {
                root.m_region.max = Vec3f();
                root.m_region.min = Vec3f();
            }

            if (root.m_childNode != null && root.m_activeNodes != 0)
            {
                for (int a = 0; a < 8; a++)
                {
                    if (root.m_childNode[a] != null)
                    {
                        root.UnloadHelper(root.m_childNode[a]);
                        root.m_childNode.erase(a);
                    }
                }
            }
            m_activeNodes = 0;
            //root.m_childNode = null;
            @root._parent = null;

        }

        // #region Rendering for debug
        void RenderReset()
        {
            //m_BranchCollection.clear();
        }

        /* // Renders the current state of the octTree by drawing the outlines of each bounding region.        
        void Render()
        {
            Vec3f<Vec3f> verts(8);

            verts[0] = m_region.min;
            verts[1] = Vec3f(m_region.min.x, m_region.min.y, m_region.max.z); //Z
            verts[2] = Vec3f(m_region.min.x, m_region.max.y, m_region.min.z); //Y
            verts[3] = Vec3f(m_region.max.x, m_region.min.y, m_region.min.z); //X

            verts[7] = m_region.max;
            verts[4] = Vec3f(m_region.max.x, m_region.max.y, m_region.min.z); //Z
            verts[5] = Vec3f(m_region.max.x, m_region.min.y, m_region.max.z); //Y
            verts[6] = Vec3f(m_region.min.x, m_region.max.y, m_region.max.z); //X


            m_BranchCollection.AddLineSegment(verts[0], verts[1], m_lineColor);
            m_BranchCollection.AddLineSegment(verts[0], verts[2], m_lineColor);
            m_BranchCollection.AddLineSegment(verts[0], verts[3], m_lineColor);
            m_BranchCollection.AddLineSegment(verts[7], verts[4], m_lineColor);
            m_BranchCollection.AddLineSegment(verts[7], verts[5], m_lineColor);
            m_BranchCollection.AddLineSegment(verts[7], verts[6], m_lineColor);

            m_BranchCollection.AddLineSegment(verts[1], verts[6], m_lineColor);
            m_BranchCollection.AddLineSegment(verts[1], verts[5], m_lineColor);
            m_BranchCollection.AddLineSegment(verts[4], verts[2], m_lineColor);
            m_BranchCollection.AddLineSegment(verts[4], verts[3], m_lineColor);
            m_BranchCollection.AddLineSegment(verts[2], verts[6], m_lineColor);
            m_BranchCollection.AddLineSegment(verts[3], verts[5], m_lineColor);           

            for (int a = 0; a < 8; a++)
            {
                if (m_childNode[a] != null)
                    m_childNode[a].Render(pb);
            }
        }

        /// Draws all objects contained in the octree collection
        void Draw(float time)
        {
            foreach (Blob3D obj in m_allObjects)
            {
                obj.Draw(time);
            }
        }
        */

        //#region Updates
        void UpdateObjects(float time)
        {
            //handle all pending object insertions, movements, tree construction, etc.
            if (m_pendingInsertion.length() > 0)
                ProcessPendingItems();

            UpdateTreeObjects(this, time);
            //UpdateTree(movedObjects);
            PruneDeadBranches(this);

        }

        /// This updates the structure of the tree based on the position of all moved objects.
        private void UpdateTree(Blob3D@[] movedObjects)
        { 
            if (m_treeBuilt == true)
            {
                if (movedObjects.length() > 0)
                {
                    //objects have moved! update the tree structure
                    for ( int i = 0; i < movedObjects.length(); i++)
                    {
                        Blob3D@ movedObject = movedObjects[i];
                        //grab the node which this object *should* occupy
                        OcTree tgtNode = FindContainingChildnode(movedObject, m_root);
                        if (tgtNode == null)
                            FindContainingChildnode(movedObject, m_root);

                        //grab the node which this object currently occupies
                        OcTree curNode = FindObjectInTree(movedObject, m_root);

                        if (tgtNode !is curNode)
                        {
                            curNode.Remove(movedObject);
                            bool attempt = tgtNode.Insert(movedObject);
                            if (!attempt)
                            {
                                //DEBUG
                                bool result = tgtNode.Insert(movedObject);

                                Blob3D@[] tmp = m_root.AllObjects();
                                UnloadContent();
                                @m_root = OcTree(AABB(Vec3f(), Vec3f()));
                                Enqueue(tmp);
                                ProcessPendingItems();

                                //m_root.UnloadContent();
                                //Enqueue(tmp);//add to pending queue
                                //m_root.m_objects.AddRange(tmp);

                                //m_objects.push_back(Item);
                                //BuildTree();
                            }

                            //the object no longer fits in the tree
                            //if (curNode != null)
                            //{
                            //    curNode.m_objects.Remove(movedObject);
                            //}
                            //else
                            //{
                            //}
                        }
                    }

                    
                }
            }
            else
            {
                //build the tree
            }
        }

        void Update(float time)
        {
            if (m_treeBuilt == true && m_treeReady == true)
            {
                //Start a count down death timer for any leaf nodes which don't have objects or children.
                //when the timer reaches zero, we delete the leaf. If the node is reused before death, we double its lifespan.
                //this gives us a "frequency" usage score and lets us avoid allocating and deallocating memory unnecessarily
                if (m_objects.length() == 0)
                {
                    if (HasChildren == false)
                    {
                        if (m_curLife == -1)
                            m_curLife = m_maxLifespan;
                        else if (m_curLife > 0)
                        {
                            m_curLife--;
                        }
                    }
                }
                else
                {
                    if (m_curLife != -1)
                    {
                        if (m_maxLifespan <= 64)
                            m_maxLifespan *= 2;
                        m_curLife = -1;
                    }
                }

                Blob3D[] movedObjects = Blob3D[](m_objects.length());

                //go through and update every object in the current tree node
                for( uint i = 0; i < m_objects.length(); i++)
                {
                    Blob3D@ gameObj = m_objects[i];
                    //we should figure out if an object actually moved so that we know whether we need to update this node in the tree.
                    if (gameObj.Update(time) == 1)
                    {
                        movedObjects.push_back(gameObj);
                    }
                }

                //prune any dead objects from the tree.
                int listSize = m_objects.length();
                for (int a = 0; a < listSize; a++)
                {
                    if (!m_objects[a].Alive)
                    {
                        if (movedObjects.Contains(m_objects[a]))
                            movedObjects.Remove(m_objects[a]);
                        m_objects.RemoveAt(a--);
                        listSize--;
                    }
                }

                int flags = m_activeNodes;
                //prune out any dead branches in the tree
                for (int index = 0; flags > 0; index++)
                {
                    flags >>= 1;
                    if ((flags & 1) == 1 && m_childNode[index].m_curLife == 0)
                    {
                        if (m_childNode[index].m_objects.length() > 0)
                        {
                            //throw Exception("Tried to delete a used branch!");
                            m_childNode[index].m_curLife = -1;
                        }
                        else
                        {
                            m_childNode[index] = null;
                            m_activeNodes ^= (byte)(1 << index);       //remove the node from the active nodes flag list
                        }
                    }
                }

                flags = m_activeNodes;
                //recursively update any child nodes.
                for (int index = 0; flags > 0; index++)
                {
                    flags >>= 1;
                    if ((flags & 1) == 1)
                    {
                        if(m_childNode!=null && m_childNode[index] != null)
                            m_childNode[index].Update(time);
                    }
                }



                //If an object moved, we can insert it into the parent and that will insert it into the correct tree node.
                //note that we have to do this last so that we don't accidentally update the same object more than once per frame.
                for( uint i = 0; i < movedObjects.length(); i++)
                {
                    Blob3D@ movedObj = movedObjects[i];
                    OcTree current = this;                    

                    //figure out how far up the tree we need to go to reinsert our moved object
                    //we are either using a bounding rect or a bounding sphere
                    //try to move the object into an enclosing parent node until we've got full containment
                    if (movedObj.EnclosingBox.max != movedObj.EnclosingBox.min)
                    {
                        while (current.m_region.Contains(movedObj.EnclosingBox) != ContainmentType.Contains)
                            if (current._parent != null) current = current._parent;
                            else
                            {
                                break; //prevent infinite loops when we go out of bounds of the root node region
                            }
                    }
                    else
                    {
                        ContainmentType ct = current.m_region.Contains(movedObj.EnclosingSphere);
                        while (ct != ContainmentType.Contains)//we must be using a bounding sphere, so check for its containment.
                        {
                            if (current._parent != null)
                            {
                                current = current._parent;
                            }
                            else
                            {
                                //the root region cannot contain the object, so we need to completely rebuild the whole tree.
                                //The rarity of this event is rare enough where we can afford to take all objects out of the existing tree and rebuild the entire thing.
                                Blob3D[] tmp = m_root.AllObjects();
                                m_root.UnloadContent();
                                Enqueue(tmp);//add to pending queue

                                
                                return;
                            }

                            ct = current.m_region.Contains(movedObj.EnclosingSphere);
                        }
                    }

                        //now, remove the object from the current node and insert it into the current containing node.
                    m_objects.Remove(movedObj);
                    current.Insert(movedObj);   //this will try to insert the object as deep into the tree as we can go.
                }

                //if (bContained == false)
                //{
                //    Blob3D[] objList = AllObjects();
                //    foreach (Blob3D p in objList)
                //        m_pendingInsertion.Enqueue(p);
                //    m_treeBuilt = false;
                //    UpdateTree();
                //}
                

                //now that all objects have moved and they've been placed into their correct nodes in the octree, we can look for collisions.
                if (IsRoot == true)
                {
                    //This will recursively gather up all collisions and create a list of them.
                    //this is simply a matter of comparing all objects in the current root node with all objects in all child nodes.
                    //note: we can assume that every collision will only be between objects which have moved.
                    //note 2: An explosion can be centered on a point but grow in size over time. In this case, you'll have to override the update method for the explosion.
                    IntersectionRecord[] irList = GetIntersection(Blob3D[]());

                    for( uint i = 0; i < irList.length(); i++)
                    {
                        IntersectionRecord@ ir = irList[i];
                        if (ir.PhysicalObject != null)
                            ir.PhysicalObject.HandleIntersection(ir);
                        if (ir.OtherPhysicalObject != null)
                            ir.OtherPhysicalObject.HandleIntersection(ir);
                    }
                }
            }//end if tree built
            else
            {
                if (m_pendingInsertion.length() > 0)
                {
                    ProcessPendingItems();
                    Update(time);   //try this again...
                }
            }
        }

        /// <summary>
        /// Inserts a bunch of items into the oct tree.
        
        /// <param name="ItemList">A list of Blob3D objects to add</param>
        /// <remarks>The OcTree will be rebuilt JIT</remarks>
        void Enqueue(Blob3D@[] ItemList)
        {
            for (int i = 0; i < ItemList.length(); i++)
            {
                Blob3D@ Item = ItemList[i];
                if (Item.HasBounds)
                {
                    m_pendingInsertion.Enqueue(Item);
                    m_treeReady = false;
                }
                else
                {
                    warn("Every object being inserted into the octTree must have a bounding region!");
                }
            }

        }

        void Enqueue(Blob3D Item)
        {
            if (Item.HasBounds) //sanity check
            {
                //are we trying to add at the root node? If so, we can assume that the user doesn't know where in the tree it needs to go.
                if (_parent == null)
                {
                    m_pendingInsertion.Enqueue(Item);

                    m_treeReady = false;    //mark the tree as needing an update
                }
                else
                {
                    //the user is giving us a hint on where in the tree they think the object should go. Let's try to insert as close to the hint as possible.
                    OcTree current = this;

                    //push the object up the tree until we find a region which contains it
                    if (Item.EnclosingBox.max != Item.EnclosingBox.min)
                    {
                        while (current.m_region.Contains(Item.EnclosingBox) != ContainmentType.Contains)
                            if (current._parent != null) current = current._parent;
                            else break; //prevent infinite loops when we go out of bounds of the root node region
                    }
                    else
                    {
                        while (current.m_region.Contains(Item.EnclosingSphere) != ContainmentType.Contains)//we must be using a bounding sphere, so check for its containment.
                            if (current._parent != null) current = current._parent;
                            else break;
                    }

                    //push the object down the tree if we can.
                    current.Insert(Item);
                }
            }
            else
            {
                throw Exception("Every object being inserted into the octTree must have a bounding region!");
            }
        }

        //I don't think I actually use this. The octree removes items on its own when they die.
        bool Remove(Blob3D Item)
        {
            //not recursive
            if (m_allObjects.Contains(Item))
            {
                m_allObjects.Remove(Item);
                return true;
            }
            return false;
        }

        /// <summary>
        /// A tree has already been created, so we're going to try to insert an item into the tree without rebuilding the whole thing
        
        /// <typeparam name="T">A Blob3D object</typeparam>
        /// <param name="Item">The Blob3D object to insert into the tree</param>
        private bool Insert(Blob3D Item)
        {
            /*if the current node is an empty leaf node, just insert and leave it.*/
            //if (m_objects.length() == 0 && m_activeNodes == 0)
            if(AllTreeObjects.length() == 0)
            {
                m_objects.push_back(Item);
                return true;
            }

            //Check to see if the dimensions of the box are greater than the minimum dimensions.
            //If we're at the smallest size, just insert the item here. We can't go any lower!
            Vec3f dimensions = m_region.max - m_region.min;
            if (dimensions.x <= MIN_SIZE && dimensions.y <= MIN_SIZE && dimensions.z <= MIN_SIZE)
            {
                m_objects.push_back(Item);
                return true;
            }

            //The object won't fit into the current region, so it won't fit into any child regions.
            //therefore, try to push it up the tree. If we're at the root node, we need to resize the whole tree.
            if (m_region.Contains(Item.EnclosingSphere) != ContainmentType.Contains)
            {
                if (this._parent != null)
                    return this._parent.Insert(Item);
                else
                    return false;
            }
            
            //At this point, we at least know this region can contain the object but there are child nodes. Let's try to see if the object will fit
            //within a subregion of this region.

            Vec3f half = dimensions / 2.0f;
            Vec3f center = m_region.min + half;

            //Find or create subdivided regions for each octant in the current region
            AABB[] childOctant = AABB[8];
            childOctant[0] = (m_childNode[0] != null) ? m_childNode[0].m_region : AABB(m_region.min, center);
            childOctant[1] = (m_childNode[1] != null) ? m_childNode[1].m_region : AABB(Vec3f(center.x, m_region.min.y, m_region.min.z), Vec3f(m_region.max.x, center.y, center.z));
            childOctant[2] = (m_childNode[2] != null) ? m_childNode[2].m_region : AABB(Vec3f(center.x, m_region.min.y, center.z), Vec3f(m_region.max.x, center.y, m_region.max.z));
            childOctant[3] = (m_childNode[3] != null) ? m_childNode[3].m_region : AABB(Vec3f(m_region.min.x, m_region.min.y, center.z), Vec3f(center.x, center.y, m_region.max.z));
            childOctant[4] = (m_childNode[4] != null) ? m_childNode[4].m_region : AABB(Vec3f(m_region.min.x, center.y, m_region.min.z), Vec3f(center.x, m_region.max.y, center.z));
            childOctant[5] = (m_childNode[5] != null) ? m_childNode[5].m_region : AABB(Vec3f(center.x, center.y, m_region.min.z), Vec3f(m_region.max.x, m_region.max.y, center.z));
            childOctant[6] = (m_childNode[6] != null) ? m_childNode[6].m_region : AABB(center, m_region.max);
            childOctant[7] = (m_childNode[7] != null) ? m_childNode[7].m_region : AABB(Vec3f(m_region.min.x, center.y, center.z), Vec3f(center.x, m_region.max.y, m_region.max.z));

            //First, is the item completely contained within the root bounding box?
            //note2: I shouldn't actually have to compensate for this. If an object is out of our predefined bounds, then we have a problem/error.
            //          Wrong. Our initial bounding box for the terrain is constricting its height to the highest peak. Flying units will be above that.
            //             Fix: I resized the enclosing box to 256x256x256. This should be sufficient.
            if (Item.EnclosingBox.max != Item.EnclosingBox.min && m_region.Contains(Item.EnclosingBox) == ContainmentType.Contains)
            {
                bool found = false;
                //we will try to place the object into a child node. If we can't fit it in a child node, then we insert it into the current node object list.
                for(int a=0;a<8;a++)
                {
                    //is the object fully contained within a quadrant?
                    if (childOctant[a].Contains(Item.EnclosingBox) == ContainmentType.Contains)
                    {
                        if (m_childNode[a] != null)
                        {
                            return m_childNode[a].Insert(Item);   //Add the item into that tree and let the child tree figure out what to do with it
                        }
                        else
                        {
                            m_childNode[a] = CreateNode(childOctant[a], Item);   //create a tree node with the item
                            m_activeNodes |= (byte)(1 << a);
                        }
                        found = true;
                    }
                }

                //we couldn't fit the item into a smaller box, so we'll have to insert it in this region
                if (!found)
                {
                    m_objects.push_back(Item);
                    return true;
                }
            }
            else if (Item.EnclosingSphere.Radius != 0 && m_region.Contains(Item.EnclosingSphere) == ContainmentType.Contains)
            {
                bool found = false;
                //we will try to place the object into a child node. If we can't fit it in a child node, then we insert it into the current node object list.
                for (int a = 0; a < 8; a++)
                {
                    //is the object contained within a child quadrant?
                    if (childOctant[a].Contains(Item.EnclosingSphere) == ContainmentType.Contains)
                    {
                        if (m_childNode[a] != null)
                        {
                            return m_childNode[a].Insert(Item);   //Add the item into that tree and let the child tree figure out what to do with it
                        }
                        else
                        {
                            m_childNode[a] = CreateNode(childOctant[a], Item);   //create a tree node with the item
                            m_activeNodes |= (byte)(1 << a);
                        }
                        found = true;
                    }
                }

                //we couldn't fit the item into a smaller box, so we'll have to insert it in this region
                if (!found)
                {
                    m_objects.push_back(Item);
                    return true;
                }
            }

            //either the item lies outside of the enclosed bounding box or it is intersecting it. Either way, we need to rebuild
            //the entire tree by enlarging the containing bounding box
            return false;
        }

        /// <summary>
        /// RECURSIVE:
        /// Naively builds an oct tree from scratch
        
        private void BuildTree()    //complete & tested
        {
            //terminate the recursion if we're a leaf node
            if (m_objects.length() <= 1)
            {
                if (m_objects.length() == 1 && m_region.Contains(m_objects[0].EnclosingSphere) == ContainmentType.Contains)
                {
                    return;
                }
            }

            Vec3f dimensions = m_region.max - m_region.min;

            if (dimensions == Vec3f())
            {
                AABB tightBox = Calc.FindEnclosingAABB(m_objects);
                m_region = Calc.FindEnclosingCube(tightBox);
                dimensions = m_region.max - m_region.min;
            }

            //Check to see if the dimensions of the box are greater than the minimum dimensions
            if (dimensions.x <= MIN_SIZE && dimensions.y <= MIN_SIZE && dimensions.z <= MIN_SIZE)
            {
                return;
            }

            Vec3f half = dimensions / 2.0f;
            Vec3f center = m_region.min + half;

            //Create subdivided regions for each octant
            AABB[] octant = AABB[8];
            octant[0] = AABB(m_region.min, center);
            octant[1] = AABB(Vec3f(center.x, m_region.min.y, m_region.min.z), Vec3f(m_region.max.x, center.y, center.z));
            octant[2] = AABB(Vec3f(center.x, m_region.min.y, center.z), Vec3f(m_region.max.x, center.y, m_region.max.z));
            octant[3] = AABB(Vec3f(m_region.min.x, m_region.min.y, center.z), Vec3f(center.x, center.y, m_region.max.z));
            octant[4] = AABB(Vec3f(m_region.min.x, center.y, m_region.min.z), Vec3f(center.x, m_region.max.y, center.z));
            octant[5] = AABB(Vec3f(center.x, center.y, m_region.min.z), Vec3f(m_region.max.x, m_region.max.y, center.z));
            octant[6] = AABB(center, m_region.max);
            octant[7] = AABB(Vec3f(m_region.min.x, center.y, center.z), Vec3f(center.x, m_region.max.y, m_region.max.z));

            //This will contain all of our objects which fit within each respective octant.
            Blob3D[][] octList = Blob3D[][8];
            for (int i = 0; i < 8; i++) octList[i] = Blob3D[]();

            //this list contains all of the objects which got moved down the tree and can be delisted from this node.
            Blob3D[] delist = Blob3D[]();

            for (int i = 0; i < m_objects.length(); i++)
            {
                Blob3D@ obj = m_objects[i];
                if (obj.EnclosingBox.min != obj.EnclosingBox.max)
                {
                    for (int a = 0; a < 8; a++)
                    {
                        if (octant[a].Contains(obj.EnclosingBox) == ContainmentType.Contains)
                        {
                            octList[a].push_back(obj);
                            delist.push_back(obj);
                            break;
                        }
                    }
                }
                else if (obj.EnclosingSphere.Radius != 0)
                {
                    for (int a = 0; a < 8; a++)
                    {
                        if (octant[a].Contains(obj.EnclosingSphere) == ContainmentType.Contains)
                        {
                            octList[a].push_back(obj);
                            delist.push_back(obj);
                            break;
                        }
                    }
                }
            }

            //delist every moved object from this node.
            for (int i = 0; i < delist.length(); i++)
                m_objects.Remove(delist[i]);

            if (m_childNode == null)
                m_childNode = OcTree[8];
            //m_activeNodes = 0;

            //Create child nodes where there are items contained in the bounding region
            for (int a = 0; a < 8; a++)
            {
                if (octList[a].length() != 0)
                {
                    m_childNode[a] = CreateNode(octant[a], octList[a]);
                    m_activeNodes |= (byte)(1 << a);
                    m_childNode[a].BuildTree();
                }
            }

            //m_treeBuilt = true;
            //m_treeReady = true;
        }

        private void SimpleTreeInit()
        {
            //clean out any exist tree data
            //m_root = OcTree();
            m_root = this;

            UnloadContent();

            AABB tightBox = Calc.FindEnclosingAABB(m_allObjects);
            m_region = Calc.FindEnclosingCube(tightBox);

            m_objects.AddRange(m_allObjects);

            SimpleTreeBuildHelper(m_root);

            m_treeReady = true;
            m_treeBuilt = true;
        }

        private void SimpleTreeBuildHelper(OcTree currentNode)
        {
            //since this node only has one object, we don't have to subdivide it anymore.
            if (currentNode.m_objects.length() == 1)
                return;

            AABB[] octants = GetSubdividedOctants(currentNode);

            //This will contain all of our objects which fit within each respective octant.
            Blob3D[][] octList = Blob3D[][8];
            for (int i = 0; i < 8; i++) octList[i] = Blob3D[]();

            //this list contains all of the objects which got moved down the tree and can be delisted from this node.
            Blob3D[] delist = Blob3D[]();

            for( uint i = 0; i < currentNode.m_objects.length(); i++)
            {
                Blob3D@ obj = currentNode.m_objects[i];
                int index = FindContainingRegion(obj, octants);

                if (index >= 0)
                {
                    octList[index].push_back(obj);
                    delist.push_back(obj);
                }
            }

            //delist every placed object from this nodes list of objects.
            for( uint i = 0; i < delist.length(); i++)
            {
                Blob3D@ obj = delist[i];
                currentNode.m_objects.Remove(obj);
            }

            if (currentNode.m_childNode == null)
                currentNode.m_childNode = OcTree[8];

            for (int a = 0; a < 8; a++)
            {
                if (octList[a].length() != 0)
                {
                    currentNode.m_childNode[a] = CreateNode(octants[a], octList[a]);
                    currentNode.m_activeNodes |= (byte)(1 << a);
                    currentNode.SimpleTreeBuildHelper(currentNode.m_childNode[a]);
                }
            }
        }

        void SimpleTreeUpdate(float worldTime)
        {

            if (IsEmpty) return;

            //BaseSettings.StartPerf("Tree Build");       //~250fps
            //rebuild the whole tree
            if (m_treeReady == false)
            {
                SimpleTreeInit();
            }
            //BaseSettings.StopPerf("Tree Build");

            //update all objects in the collection
            //BaseSettings.StartPerf("Tree Object Update");       //~30fps
            BaseSettings.StartPerfColl("Tree Object Update", m_allObjects.length());
            int count = m_allObjects.length();
            for (int a = 0; a < count;a++ )
            {
                BaseSettings.StartPerfCollItem("Tree Object Update", a);
                int status = m_allObjects[a].Update(worldTime);
                BaseSettings.StopPerfCollItem("Tree Object Update", a);

                if(status != 0)
                {
                    m_treeReady = false;
                }

                if (status == 2)
                {
                    m_allObjects.Remove(m_allObjects[a--]);
                    count--;
                    continue;
                }

            }
            BaseSettings.StopPerfColl("Tree Object Update");
            //BaseSettings.StopPerf("Tree Object Update");

            
        }

        void SimpleTreeAdd(Blob3D Item)
        {
            m_treeReady = false;
            m_allObjects.push_back(Item);
        }

        void SimpleTreeAdd(Blob3D[] ItemList)
        {
            m_treeReady = false;
            m_allObjects.AddRange(ItemList);
        }

        void SimpleTreeRemove(Blob3D[] Item)
        {
            m_treeReady = false;
            m_allObjects.Remove(Item);
        }

        /// <summary>
        /// This will try to find where to place the item within a bounding region.
        
        /// <param name="item">The item to be placed</param>
        /// <param name="regions">An array of 8 bounding boxes to try to place the item into</param>
        /// <returns>
        /// -2: Input parameters are null!
        /// -1: The object could not be placed
        /// 0-7: The index of the bounding box which the item can be contained within</returns>
        private int FindContainingRegion(Blob3D Item, AABB[] regions)
        {
            if (Item == null) return -2;
            if (regions == null) return -2;

            if (Item.EnclosingBox.max != Item.EnclosingBox.min)
            {
                //we will try to place the object into a child node. If we can't fit it in a child node, then we insert it into the current node object list.
                for (int a = 0; a < 8; a++)
                {
                    //is the object fully contained within a quadrant?
                    if (regions[a].Contains(Item.EnclosingBox) == ContainmentType.Contains)
                    {
                        return a;
                    }
                }
            }
            else if (Item.EnclosingSphere.Radius != 0)
            {
                //we will try to place the object into a child node. If we can't fit it in a child node, then we insert it into the current node object list.
                for (int a = 0; a < 8; a++)
                {
                    //is the object contained within a child quadrant?
                    if (regions[a].Contains(Item.EnclosingSphere) == ContainmentType.Contains)
                    {
                        return a;
                    }
                }
            }

            return -1;
        }

        /// <summary>
        /// Calculates the sub octant regions for the given region
        
        /// <param name="region">A non-zero sized region of space</param>
        /// <returns>An array containing 8 bounding boxes which subdivide the given region</returns>
        private AABB[] GetSubdividedOctants(AABB region)
        {
            Vec3f dimensions = region.max - region.min;

            if (dimensions == Vec3f())
            {
                //return null;
                throw Exception("zero dimension regions cant be split!");
            }

            Vec3f half = dimensions / 2.0f;
            Vec3f center = region.min + half;

            //Create subdivided regions for each octant
            AABB[] octant = AABB[8];
            octant[0] = AABB(region.min, center);
            octant[1] = AABB(Vec3f(center.x, region.min.y, region.min.z), Vec3f(region.max.x, center.y, center.z));
            octant[2] = AABB(Vec3f(center.x, region.min.y, center.z), Vec3f(region.max.x, center.y, region.max.z));
            octant[3] = AABB(Vec3f(region.min.x, region.min.y, center.z), Vec3f(center.x, center.y, region.max.z));
            octant[4] = AABB(Vec3f(region.min.x, center.y, region.min.z), Vec3f(center.x, region.max.y, center.z));
            octant[5] = AABB(Vec3f(center.x, center.y, region.min.z), Vec3f(region.max.x, region.max.y, center.z));
            octant[6] = AABB(center, region.max);
            octant[7] = AABB(Vec3f(region.min.x, center.y, center.z), Vec3f(center.x, region.max.y, region.max.z));

            return octant;
        }

        /// <summary>
        /// Finds/Creates a list of subdivided octants for the given node. If the node already contains a few subdivided octants,
        /// it will use those existing regions.
        
        /// <param name="currentNode">The current node to find subdivided regions for</param>
        /// <returns>An 8 element array of bounding boxes indicating the subdivided regions</returns>
        private AABB[] GetSubdividedOctants(OcTree currentNode)
        {
            Vec3f dimensions = currentNode.m_region.max - currentNode.m_region.min;

            if (dimensions == Vec3f())
            {
                //return null;
                throw Exception("zero dimension regions cant be split!");
            }

            Vec3f half = dimensions / 2.0f;
            Vec3f center = currentNode.m_region.min + half;

            AABB[] childOctant = AABB[8];
            childOctant[0] = (currentNode.m_childNode[0] != null) ? currentNode.m_childNode[0].m_region : AABB(currentNode.m_region.min, center);
            childOctant[1] = (currentNode.m_childNode[1] != null) ? currentNode.m_childNode[1].m_region : AABB(Vec3f(center.x, currentNode.m_region.min.y, currentNode.m_region.min.z), Vec3f(currentNode.m_region.max.x, center.y, center.z));
            childOctant[2] = (currentNode.m_childNode[2] != null) ? currentNode.m_childNode[2].m_region : AABB(Vec3f(center.x, currentNode.m_region.min.y, center.z), Vec3f(currentNode.m_region.max.x, center.y, currentNode.m_region.max.z));
            childOctant[3] = (currentNode.m_childNode[3] != null) ? currentNode.m_childNode[3].m_region : AABB(Vec3f(currentNode.m_region.min.x, currentNode.m_region.min.y, center.z), Vec3f(center.x, center.y, currentNode.m_region.max.z));
            childOctant[4] = (currentNode.m_childNode[4] != null) ? currentNode.m_childNode[4].m_region : AABB(Vec3f(currentNode.m_region.min.x, center.y, currentNode.m_region.min.z), Vec3f(center.x, currentNode.m_region.max.y, center.z));
            childOctant[5] = (currentNode.m_childNode[5] != null) ? currentNode.m_childNode[5].m_region : AABB(Vec3f(center.x, center.y, currentNode.m_region.min.z), Vec3f(currentNode.m_region.max.x, currentNode.m_region.max.y, center.z));
            childOctant[6] = (currentNode.m_childNode[6] != null) ? currentNode.m_childNode[6].m_region : AABB(center, currentNode.m_region.max);
            childOctant[7] = (currentNode.m_childNode[7] != null) ? currentNode.m_childNode[7].m_region : AABB(Vec3f(currentNode.m_region.min.x, center.y, center.z), Vec3f(center.x, currentNode.m_region.max.y, currentNode.m_region.max.z));

            return childOctant;
        }

        private OcTree CreateNode(AABB region, Blob3D[] objList)  //complete & tested
        {
            if (objList.length() == 0)
                return null;

            OcTree ret = OcTree(region, objList);
            ret._parent = this;

            return ret;
        }

        private OcTree CreateNode(AABB region, Blob3D Item)
        {
            Blob3D[] objList = Blob3D[](1); //sacrifice potential CPU time for a smaller memory footprint
            objList.push_back(Item);
            OcTree ret = OcTree(region, objList);
            ret._parent = this;
            return ret;
        }

        /// <summary>
        /// This grabs the current container being occupied by the object.
        
        /// <param name="myObject">The object you're looking for</param>
        /// <param name="searchNode">The node you want to start searching in</param>
        /// <returns>Null: no container was found
        /// Octree: the container which currently holds the object</returns>
        private OcTree FindObjectInTree(Blob3D myObject, OcTree currentNode)
        {
            if (currentNode.m_objects.Contains(myObject))
            {
                return currentNode;
            }
            else
            {
                //Create subdivided regions for each octant
                AABB[] octant = GetSubdividedOctants(currentNode.m_region);


                if (myObject.EnclosingBox.min != myObject.EnclosingBox.max)
                {
                    for (int a = 0; a < 8; a++)
                    {
                        if (octant[a].Contains(myObject.EnclosingBox) == ContainmentType.Contains)
                        {
                            if (currentNode.m_childNode[a] != null)
                                return FindObjectInTree(myObject, currentNode.m_childNode[a]);
                            else
                                break;
                        }
                    }
                }
                else if (myObject.EnclosingSphere.Radius != 0)
                {
                    for (int a = 0; a < 8; a++)
                    {
                        if (octant[a].Contains(myObject.EnclosingSphere) == ContainmentType.Contains)
                        {
                            if (currentNode.m_childNode[a] != null)
                                return FindObjectInTree(myObject, currentNode.m_childNode[a]);
                            else
                                break;
                        }
                    }
                }

                //we couldn't fit the object into any child nodes and its not in the current node. There's only one last possibility:
                //the object is in a child node but has moved such that it intersects two bounding boxes. In that case, one of the child
                //nodes may still contain the object.
                return FindObjectByBrute(myObject, currentNode);
            }
        }

        private OcTree FindObjectByBrute(Blob3D myObject, OcTree currentNode)
        {
            if (currentNode.m_objects.Contains(myObject))
                return currentNode;
            else
            {
                if (currentNode.HasChildren)
                {
                    for (int a = 0; a < 8; a++)
                    {
                        if (currentNode.m_childNode[a] != null)
                        {
                            OcTree result = FindObjectByBrute(myObject, currentNode.m_childNode[a]);
                            if (result != null)
                                return result;
                        }
                    }
                }
                return null;
            }
        }

        private OcTree@ FindContainingChildnode(Blob3D@ myObject, OcTree@ currentNode)
        {
            //if (m_objects.Contains(myObject))
            //{
            //    return this;
            //}

            //We aren't looking for the object within a node, we're just looking for the node which should contain the object.
            AABB[] octant = GetSubdividedOctants(currentNode.m_region);

            if (myObject.EnclosingBox.min != myObject.EnclosingBox.max)
            {
                for (int a = 0; a < 8; a++)
                {
                    if (octant[a].Contains(myObject.EnclosingBox) == ContainmentType.Contains)
                    {
                        if (currentNode.m_childNode[a] != null)
                            return FindContainingChildnode(myObject, currentNode.m_childNode[a]);
                        else
                            break;
                    }
                }
            }
            else if (myObject.EnclosingSphere.Radius != 0)
            {
                for (int a = 0; a < 8; a++)
                {
                    if (octant[a].Contains(myObject.EnclosingSphere) == ContainmentType.Contains)
                    {
                        if (currentNode.m_childNode[a] != null)
                            return FindContainingChildnode(myObject, currentNode.m_childNode[a]);
                        else
                            break;
                    }
                }
            }

            //we couldn't fit the object into any child nodes and its not in the current node. There's only one last possibility:
            //the object is in a child node but has moved such that it intersects two bounding boxes. In that case, one of the child
            //nodes may still contain the object.
            return currentNode;
        }

        private void PruneDeadBranches(OcTree currentNode)
        {
            //Start a count down death timer for any leaf nodes which don't have objects or children.
            //when the timer reaches zero, we delete the leaf. If the node is reused before death, we double its lifespan.
            //this gives us a "frequency" usage score and lets us avoid allocating and deallocating memory unnecessarily

            //if (currentNode == null)
               // ExportXML();

            if (currentNode.m_objects.length() == 0)           //node is empty
            {
                if (currentNode.HasChildren == false)       //node is a leaf node with no objects
                {
                    if (currentNode.m_curLife == -1)        //node countdown timer is inactive
                        currentNode.m_curLife = currentNode.m_maxLifespan;
                    else if (currentNode.m_curLife > 0)                 //node countdown time is active
                    {
                        currentNode.m_curLife--;
                    }
                }
            }
            else
            {
                if (currentNode.m_curLife != -1)            //node countdown timer is active and it now has objects!
                {
                    if (currentNode.m_maxLifespan <= 64)    //double the max life of the timer and reset the timer
                        currentNode.m_maxLifespan *= 2;
                    currentNode.m_curLife = -1;
                }
            }

            //prune out any dead branches in the tree
            for (int flags = currentNode.m_activeNodes, index = 0; flags > 0; flags >>= 1, index++)
            {
                if ((flags & 1) == 1)                                           //is this an active child node?
                {
                    PruneDeadBranches(currentNode.m_childNode[index]);          //try to recursively prune any dead child nodes

                    if (currentNode.m_childNode[index].m_curLife == 0)          //has the death timer completed?
                    {
                        if (currentNode.m_childNode[index].m_objects.length() > 0)
                        {
                            /*If this happens, an object moved into our node and we didn't catch it. That means we have to do a conceptual rethink on this implementation.*/
                            warn("Tried to delete a used branch!");
                            //currentNode.m_childNode[index].m_curLife = -1;
                        }
                        else
                        {
                            currentNode.m_childNode[index] = null;
                            currentNode.m_activeNodes ^= (byte)(1 << index);       //remove the node from the active nodes flag list
                        }
                    }
                }
            }
        }

        /// Updates all objects in the given tree and gives you a list of objects which moved during their update.
        /// Will also prune out any dead objects.
        
        private void UpdateTreeObjects(OcTree currentNode, float time)
        {
            //go through and update every object in the node

            m_deadObjects.clear();
            Blob3D[] movedObjects;
            
            //Update & move all objects in the node
            for (int a = 0; a < currentNode.m_objects.length(); a++)
            {
                //we should figure out if an object actually moved so that we know whether we need to update this node in the tree.
                if (currentNode.m_objects[a].Update(time) == 1)
                    movedObjects.push_back(currentNode.m_objects[a]);

                if (!currentNode.m_objects[a].Alive)
                    m_deadObjects.push_back(currentNode.m_objects[a]);
            }

            //prune any dead objects from the tree.
            for(uint i = 0; i < m_deadObjects.length(); i++)
            {
                Blob3D@ deadObj= m_deadObjects[i];
                //maintain the moved objects list
                if (movedObjects.Contains(deadObj))
                    movedObjects.Remove(deadObj);

                //remove the object from the octree
                currentNode.m_objects.Remove(deadObj);

                //remove the object from the global objects list
                m_allObjects.Remove(deadObj);
            }

            //update any child nodes
            if (currentNode.HasChildren)
            {
                for (int flags = currentNode.m_activeNodes, index = 0; flags > 0; flags >>= 1, index++)
                {
                    if ((flags & 1) == 1)//is this an active child node?
                    {
                        UpdateTreeObjects(currentNode.m_childNode[index], time);
                    }
                }
            }

            //If an object moved, we can insert it into the parent and that will insert it into the correct tree node.
            //note that we have to do this last so that we don't accidentally update the same object more than once per frame.
           
            for(uint i = 0; i < movedObjects.length(); i++)
            {
                Blob3D@ movedObj = movedObjects[i];
                OcTree current = currentNode;
                currentNode.Remove(movedObj);

                //figure out how far up the tree we need to go to reinsert our moved object
                //we are either using a bounding rect or a bounding sphere
                //try to move the object into an enclosing parent node until we've got full containment
                if (movedObj.EnclosingBox.max != movedObj.EnclosingBox.min)
                {
                    while (current.m_region.Contains(movedObj.EnclosingBox) != ContainmentType.Contains)
                        if (current._parent != null) current = current._parent;
                        else
                        {
                            break; //prevent infinite loops when we go out of bounds of the root node region
                        }
                }
                else
                {
                    ContainmentType ct = current.m_region.Contains(movedObj.EnclosingSphere);
                    while (ct != ContainmentType.Contains)//we must be using a bounding sphere, so check for its containment.
                    {
                        if (current._parent != null)
                        {
                            current = current._parent;
                        }
                        else
                        {
                            //the root region cannot contain the object, so we need to completely rebuild the whole tree.
                            //The rarity of this event is rare enough where we can afford to take all objects out of the existing tree and rebuild the entire thing.
                            Blob3D[]@ tmp = m_root.AllObjects();
                            m_root.UnloadContent();
                            Enqueue(tmp);//add to pending queue
                            return;
                        }
                        ct = current.m_region.Contains(movedObj.EnclosingSphere);
                    }
                }

                //now, remove the object from the current node and insert it into the current containing node.
                //m_objects.Remove(movedObj);
                current.Insert(movedObj); //this will try to insert the object as deep into the tree as we can go.
            }

            ////all objects which have moved need to be tested to see if they still belong in the current node
            //for(uint i = 0; i < movedObjects.length(); i++)
            //{
            //    Blob3D@ movedObj = movedObjects[i];
            //    UpdateMovedObjectTreePosition(currentNode, movedObj);
            //}
        }

        private bool UpdateMovedObjectTreePosition(OcTree currentNode, Blob3D Item)
        {
            /*if the current node is an empty leaf node, just insert and leave it.*/
            //if (m_objects.length() == 0 && m_activeNodes == 0)
            if (currentNode.AllTreeObjects.length() == 0)
            {
                currentNode.m_objects.push_back(Item);
                return true;
            }

            //Check to see if the dimensions of the box are greater than the minimum dimensions.
            //If we're at the smallest size, just insert the item here. We can't go any lower!
            Vec3f dimensions = currentNode.m_region.max - currentNode.m_region.min;
            if (dimensions.x <= MIN_SIZE && dimensions.y <= MIN_SIZE && dimensions.z <= MIN_SIZE)
            {
                currentNode.m_objects.push_back(Item);
                return true;
            }

            //The object won't fit into the current region, so it won't fit into any child regions.
            //therefore, try to push it up the tree. If we're at the root node, we need to resize the whole tree.
            if (currentNode.m_region.Contains(Item.EnclosingSphere) != ContainmentType.Contains)
            {
                if (currentNode._parent != null)
                    currentNode.UpdateMovedObjectTreePosition(_parent, Item);
                else
                {
                    //gotta rebuild the whole tree
                    Blob3D[]@ tmp = m_root.AllObjects();
                    UnloadContent();
                    m_root = OcTree(AABB(Vec3f(), Vec3f()));
                    Enqueue(tmp);
                    ProcessPendingItems();
                    return false;
                }
            }

            Vec3f half = dimensions / 2.0f;
            Vec3f center = m_region.min + half;

            //Find or create subdivided regions for each octant in the current region
            AABB[8] childOctant;
            childOctant[0] = (currentNode.m_childNode[0] != null) ? currentNode.m_childNode[0].m_region : AABB(currentNode.m_region.min, center);
            childOctant[1] = (currentNode.m_childNode[1] != null) ? currentNode.m_childNode[1].m_region : AABB(Vec3f(center.x, currentNode.m_region.min.y, currentNode.m_region.min.z), Vec3f(currentNode.m_region.max.x, center.y, center.z));
            childOctant[2] = (currentNode.m_childNode[2] != null) ? currentNode.m_childNode[2].m_region : AABB(Vec3f(center.x, currentNode.m_region.min.y, center.z), Vec3f(currentNode.m_region.max.x, center.y, currentNode.m_region.max.z));
            childOctant[3] = (currentNode.m_childNode[3] != null) ? currentNode.m_childNode[3].m_region : AABB(Vec3f(currentNode.m_region.min.x, currentNode.m_region.min.y, center.z), Vec3f(center.x, center.y, currentNode.m_region.max.z));
            childOctant[4] = (currentNode.m_childNode[4] != null) ? currentNode.m_childNode[4].m_region : AABB(Vec3f(currentNode.m_region.min.x, center.y, currentNode.m_region.min.z), Vec3f(center.x, currentNode.m_region.max.y, center.z));
            childOctant[5] = (currentNode.m_childNode[5] != null) ? currentNode.m_childNode[5].m_region : AABB(Vec3f(center.x, center.y, currentNode.m_region.min.z), Vec3f(currentNode.m_region.max.x, currentNode.m_region.max.y, center.z));
            childOctant[6] = (currentNode.m_childNode[6] != null) ? currentNode.m_childNode[6].m_region : AABB(center, currentNode.m_region.max);
            childOctant[7] = (currentNode.m_childNode[7] != null) ? currentNode.m_childNode[7].m_region : AABB(Vec3f(currentNode.m_region.min.x, center.y, center.z), Vec3f(center.x, currentNode.m_region.max.y, currentNode.m_region.max.z));

            //First, is the item completely contained within the root bounding box?
            //note2: I shouldn't actually have to compensate for this. If an object is out of our predefined bounds, then we have a problem/error.
            // Wrong. Our initial bounding box for the terrain is constricting its height to the highest peak. Flying units will be above that.
            // Fix: I resized the enclosing box to 256x256x256. This should be sufficient.
            if (Item.EnclosingBox.max != Item.EnclosingBox.min && currentNode.m_region.Contains(Item.EnclosingBox) == ContainmentType.Contains)
            {
                bool found = false;
                //we will try to place the object into a child node. If we can't fit it in a child node, then we insert it into the current node object list.
                for (int a = 0; a < 8; a++)
                {
                    //is the object fully contained within a quadrant?
                    if (childOctant[a].Contains(Item.EnclosingBox) == ContainmentType.Contains)
                    {
                        if (currentNode.m_childNode[a] != null)
                        {
                            currentNode.m_childNode[a].UpdateMovedObjectTreePosition(currentNode.m_childNode[a], Item);   //Add the item into that tree and let the child tree figure out what to do with it
                            break;
                        }
                        else
                        {
                            currentNode.m_childNode[a] = CreateNode(childOctant[a], Item);   //create a tree node with the item
                            currentNode.m_activeNodes |= (byte)(1 << a);
                        }
                        found = true;
                    }
                }

                //we couldn't fit the item into a smaller box, so we'll have to insert it in this region
                if (!found)
                {
                    currentNode.m_objects.push_back(Item);
                }
            }
            else if (Item.EnclosingSphere.Radius != 0 && currentNode.m_region.Contains(Item.EnclosingSphere) == ContainmentType.Contains)
            {
                bool found = false;
                //we will try to place the object into a child node. If we can't fit it in a child node, then we insert it into the current node object list.
                for (int a = 0; a < 8; a++)
                {
                    //is the object contained within a child quadrant?
                    if (childOctant[a].Contains(Item.EnclosingSphere) == ContainmentType.Contains)
                    {
                        if (currentNode.m_childNode[a] != null)
                        {
                            currentNode.m_childNode[a].UpdateMovedObjectTreePosition(currentNode.m_childNode[a], Item);   //Add the item into that tree and let the child tree figure out what to do with it
                            break;
                        }
                        else
                        {
                            currentNode.m_childNode[a] = CreateNode(childOctant[a], Item);   //create a tree node with the item
                            currentNode.m_activeNodes |= (byte)(1 << a);
                        }
                        found = true;
                    }
                }

                //we couldn't fit the item into a smaller box, so we'll have to insert it in this region
                if (!found)
                {
                    currentNode.m_objects.push_back(Item);
                }
            }

            return true;
        }

        /// <summary>
        /// Processes all pending insertions by inserting them into the tree.
        
        /// <remarks>Consider deprecating this?</remarks>
        private void ProcessPendingItems()   //complete & tested
        {
            if (this._parent == null)
                m_root = this;

            if (m_objects == null)
                m_objects = Blob3D[]();

            m_allObjects.clear();
            m_allObjects.AddRange(m_pendingInsertion);

            /*I think I can just directly insert items into the tree instead of using a queue.*/
            if (!m_treeBuilt)
            {
                m_objects.AddRange(m_pendingInsertion);
                m_pendingInsertion.clear();

                //trim out any objects which have the exact same bounding areas

                BuildTree();

                m_treeBuilt = true;
                m_treeReady = true;     //we know that since no tree existed, this is the first time we're ever here.
            }
            else
            {
                //A tree structure exists already, so we just want to try to insert into the existing structure.
                //bug test: what if the pending item doesn't fit into the bounding region of the existing tree?
                while (m_pendingInsertion.length() != 0)
                {
                    Insert(m_pendingInsertion.Dequeue());
                }
            }
        }

        /*
        
        //#region Colliders

        /// <summary>
        /// Gives you a list of all intersection records which intersect or are contained within the given frustum area
        
        /// <param name="frustum">The containing frustum to check for intersection/containment with</param>
        /// <returns>A list of intersection records with collisions</returns>
        private IntersectionRecord[] GetIntersection(BoundingFrustum frustum, PhysicalType type = PhysicalType.ALL)
        {
            if (!m_treeBuilt) return null;//List<IntersectionRecord>();

            if (m_objects.length() == 0 && HasChildren == false)   //terminator for any recursion
                return null;

            IntersectionRecord[] ret;// = List<IntersectionRecord>();

            //test each object in the list for intersection
            for(uint i = 0; i < m_objects.length(); i++)
            {
                Blob3D@ obj = m_objects[i];

                //skip any objects which don't meet our type criteria
                if ((int)((int)type & (int)obj.Type) == 0)
                    continue;

                //test for intersection
                IntersectionRecord ir = obj.Intersects(frustum);
                if (ir != null) 
                    ret.push_back(ir);
            }

            //test each object in the list for intersection
            for (int a = 0; a < 8; a++)
            {
                if (m_childNode[a] != null && (frustum.Contains(m_childNode[a].m_region) == ContainmentType.Intersects || frustum.Contains(m_childNode[a].m_region) == ContainmentType.Contains))
                {
                    List<IntersectionRecord> hitList = m_childNode[a].GetIntersection(frustum, type);
                    if (hitList != null) ret.AddRange(hitList);
                }
            }
            return ret;
        }

        /// <summary>
        /// Recursively tries to intersect a bounding sphere against all other objects in the octree with the given type
        
        /// <param name="sphere">The bounding volume to intersect all other objects against</param>
        /// <param name="type">The filter for the type of objects which should be tested for hit results</param>
        /// <returns>A list of intersection records which contain the intersection information</returns>
        private List<IntersectionRecord> GetIntersection(BoundingSphere sphere, PhysicalType type = PhysicalType.ALL)
        {
            if (m_objects.length() == 0 && HasChildren == false)   //terminator for any recursion
                return null;

            List<IntersectionRecord> ret = List<IntersectionRecord>();

            //test each object in the list for intersection
            foreach (Blob3D obj in m_objects)
            {

                //skip any objects which don't meet our type criteria
                if ((int)((int)type & (int)obj.Type) == 0)
                    continue;

                //test for intersection
                IntersectionRecord ir = obj.Intersects(sphere);
                if (ir != null) 
                    ret.push_back(ir);
            }

            //test each object in the list for intersection
            for (int a = 0; a < 8; a++)
            {
                if (m_childNode[a] != null && (sphere.Contains(m_childNode[a].m_region) == ContainmentType.Intersects || sphere.Contains(m_childNode[a].m_region) == ContainmentType.Contains))
                {
                    List<IntersectionRecord> hitList = m_childNode[a].GetIntersection(sphere, type);
                    if (hitList != null)
                    {
                        foreach (IntersectionRecord ir in hitList)
                            ret.push_back(ir);
                    }
                }
            }
            return ret;
        }

        /// <summary>
        /// Gives you a list of intersection records for all objects which intersect with the given ray
        
        /// <param name="intersectRay">The ray to intersect objects against</param>
        /// <returns>A list of all intersections</returns>
        private List<IntersectionRecord> GetIntersection(Ray intersectRay, PhysicalType type = PhysicalType.ALL)
        {
            if (!m_treeBuilt) return List<IntersectionRecord>();

            if (m_objects.length() == 0 && HasChildren == false)   //terminator for any recursion
                return null;

            List<IntersectionRecord> ret = List<IntersectionRecord>();

            //the ray is intersecting this region, so we have to check for intersection with all of our contained objects and child regions.
            
            //test each object in the list for intersection
            foreach (Blob3D obj in m_objects)
            {
                //skip any objects which don't meet our type criteria
                if ((int)((int)type & (int)obj.Type) == 0)
                    continue;

                IntersectionRecord ir = obj.Intersects(intersectRay);
                if (ir != null)
                    ret.push_back(ir);

                //if (obj.AABB.max != obj.AABB.min) //we actually have a legit bounding box
                //{
                //    if (obj.AABB.Intersects(intersectRay) != null)
                //    {
                //        m_lineColor = Color.Red;
                        
                //        ir.PhysicalObject = obj;

                //        if (ir.HasHit)
                //            ret.push_back(ir);
                //    }
                //}
                
                //if (obj.BoundingSphere.Radius != 0)    //we actually have a legit bounding sphere
                //{
                //    float? testHit = obj.BoundingSphere.Intersects(intersectRay);
                //    //what about bounding spheres?!
                //    if (testHit != null)
                //    {
                //        //we actually know we have an intersection here, so why test for it again?
                //        IntersectionRecord ir = obj.Intersects(intersectRay);
                //        ir.PhysicalObject = obj;
                //        if (ir.HasHit)
                //            ret.push_back(ir);
                //    }
                //}
            }

            // test each child octant for intersection
            for (int a = 0; a < 8; a++)
            {
                if (m_childNode[a] != null && m_childNode[a].m_region.Intersects(intersectRay) != null)
                {
                    m_lineColor = Color.Red;
                    List<IntersectionRecord> hits = m_childNode[a].GetIntersection(intersectRay, type);
                    if (hits != null && hits.length() > 0)
                    {
                        ret.AddRange(hits);
                    }
                }
            }

            return ret;
        }

        private List<IntersectionRecord> GetIntersection(Blob3D[] parentObjs, PhysicalType type = PhysicalType.ALL)
        {
            List<IntersectionRecord> intersections = List<IntersectionRecord>();
            //assume all parent objects have already been processed for collisions against each other.
            //check all parent objects against all objects in our local node
            foreach (Blob3D pObj in parentObjs)
            {
                foreach (Blob3D lObj in m_objects)
                {
                    //We let the two objects check for collision against each other. They can figure out how to do the coarse and granular checks.
                    //all we're concerned about is whether or not a collision actually happened.
                    IntersectionRecord ir = pObj.Intersects(lObj);
                    if (ir != null)
                    {

                        //ir.m_treeNode = this;


                        intersections.push_back(ir);
                    }
                }
            }

            //now, check all our local objects against all other local objects in the node
            if (m_objects != null && m_objects.length() > 1)
            {
                //#region self-congratulation
                /*
                 * This is a rather brilliant section of code. Normally, you'd just have two foreach loops, like so:
                 * foreach(Blob3D lObj1 in m_objects)
                 * {
                 *      foreach(Blob3D lObj2 in m_objects)
                 *      {
                 *           //intersection check code
                 *      }
                 * }
                 * 
                 * The problem is that this runs in O(N*N) time and that we're checking for collisions with objects which have already been checked.
                 * Imagine you have a set of four items: {1,2,3,4}
                 * You'd first check: {1} vs {1,2,3,4}
                 * Next, you'd check {2} vs {1,2,3,4}
                 * but we already checked {1} vs {2}, so it's a waste to check {2} vs. {1}. What if we could skip this check by removing {1}?
                 * We'd have a total of 4+3+2+1 collision checks, which equates to O(N(N+1)/2) time. If N is 10, we are already doing half as many collision checks as necessary.
                 * Now, we can't just remove an item at the end of the 2nd for loop since that would break the iterator in the first foreach loop, so we'd have to use a
                 * regular for(int i=0;i<size;i++) style loop for the first loop and reduce size each iteration. This works...but look at the for loop: we're allocating memory for
                 * two additional variables: i and size. What if we could figure out some way to eliminate those variables?
                 * So, who says that we have to start from the front of a list? We can start from the back end and still get the same end results. With this in mind,
                 * we can completely get rid of a for loop and use a while loop which has a conditional on the capacity of a temporary list being greater than 0.
                 * since we can poll the list capacity for free, we can use the capacity as an indexer into the list items. Now we don't have to increment an indexer either!
                 * The result is below.
                 */
                /*
                /#endregion

                Blob3D[] tmp = Blob3D[](m_objects.length());
                tmp.AddRange(m_objects);
                while (tmp.length() > 0)
                {
                    foreach (Blob3D lObj2 in tmp)
                    {
                        if (tmp[tmp.length() - 1] == lObj2 || (tmp[tmp.length() - 1].IsStationary && lObj2.IsStationary))
                            continue;
                        IntersectionRecord ir = tmp[tmp.length() - 1].Intersects(lObj2);
                        if (ir != null)
                        {
                            //ir.m_treeNode = this;
                            intersections.push_back(ir);
                        }
                    }

                    //remove this object from the temp list so that we can run in O(N(N+1)/2) time instead of O(N*N)
                    tmp.RemoveAt(tmp.length()-1);
                }
            }

            //now, merge our local objects list with the parent objects list, then pass it down to all children.
            foreach (Blob3D lObj in m_objects)
                if (lObj.IsStationary == false)
                    parentObjs.push_back(lObj);
            //parentObjs.AddRange(m_objects);

            //each child node will give us a list of intersection records, which we then merge with our own intersection records.
            for (int flags = m_activeNodes, index = 0; flags > 0; flags >>= 1, index++)
            {
                if ((flags & 1) == 1)
                {
                    if(m_childNode != null && m_childNode[index] != null)
                        intersections.AddRange(m_childNode[index].GetIntersection(parentObjs, type));
                }
            }
            
            return intersections;
        }


        /// <summary>
        /// This gives you a list of every intersection record created with the intersection ray
        
        /// <param name="intersectionRay">The ray to use for intersection</param>
        /// <returns></returns>
        List<IntersectionRecord> AllIntersections(Ray intersectionRay)
        {

            return GetIntersection(intersectionRay);
        }

        /// <summary>
        /// This gives you the first object encountered by the intersection ray
        
        /// <param name="intersectionRay">The ray being used to intersect with</param>
        /// <param name="type">The type of the Blob3D object to filter for</param>
        /// <returns></returns>
        IntersectionRecord NearestIntersection(Ray intersectionRay, PhysicalType type = PhysicalType.ALL)
        {
            List<IntersectionRecord> intersections = GetIntersection(intersectionRay, type);

            IntersectionRecord nearest = null;

            foreach (IntersectionRecord ir in intersections)
            {
                if (nearest == null)
                {
                    nearest = ir;
                    continue;
                }

                if (ir.Distance < nearest.Distance)
                {
                    nearest = ir;
                }
            }

            return nearest;
        }

        /// <summary>
        /// This gives you a list of all intersections, filtered by a specific type of object
        
        /// <param name="intersectionRay">The ray to intersect with all objects</param>
        /// <param name="type">The type of Blob3D object we're interested in intersecting with</param>
        /// <returns>A list of intersections of the specified type of geometry</returns>
        List<IntersectionRecord> AllIntersections(Ray intersectionRay, PhysicalType type = PhysicalType.ALL)
        {
            List<IntersectionRecord> intersections = GetIntersection(intersectionRay, type);

            return intersections;
        }

        /// <summary>
        /// This gives you a list of all objects which [intersect or are contained within] the given frustum and meet the given object type
        
        /// <param name="region">The frustum to intersect with</param>
        /// <param name="type">The type of objects you want to filter</param>
        /// <returns>A list of intersection records for all objects intersecting with the frustum</returns>
        List<IntersectionRecord> AllIntersections(BoundingFrustum region, PhysicalType type = PhysicalType.ALL)
        {
            return GetIntersection(region, type);
        }

        /// <summary>
        /// This gives you a list of all objects which intersect with the given bounding sphere which meet the filtering criteria
        
        /// <param name="region">The bounding sphere volume to test for collisions against</param>
        /// <param name="type">The particular type of objects you want to filter (Default: Include all objects)</param>
        /// <returns>A list of intersection records which contain intersection information.</returns>
        List<IntersectionRecord> AllIntersections(BoundingSphere region, PhysicalType type = PhysicalType.ALL)
        {
            return GetIntersection(region, type);
        }

        /// <summary>
        /// This gives you a list of all objects in the tree which meet the given type filter criteria
        
        */
        /// <param name="type">BITMASK: This is the object type to match on</param>
        /// <returns>A list of matched objects</returns>
        Blob3D@[] AllObjects(PhysicalType type = PhysicalType::ALL)
        {

            if (type == PhysicalType.ALL)
                return m_allObjects;

            Blob3D[] ret = Blob3D[](m_allObjects.length());

            //you know... if you were smart, you'd maintain a list for each object type or at least sort the objects.
            //then you could just merge lists together rather than going through each individual object and testing for a match.

            for(int i = 0; i < m_allObjects.length(); i++)
            {
                Blob3D@ p = m_allObjects[i];
                int typeMatch = int(p.Type & type);   //untested

                if (typeMatch != 0)
                {
                    ret.push_back(p);
                }
            }

            return ret;
        }



        string ToString()
        {
            string obj = (m_objects == null) ? "0" : m_objects.length().ToString();
            if (_parent == null)
            {
                string children = "";
                if (m_childNode != null)
                {
                    for (int a = 0; a < 8; a++)
                    {
                        children += "[";
                        if (m_childNode[a] != null)
                            children += m_childNode[a].AllTreeObjects.length();
                        else
                            children += "0";
                        children += "]";
                    }
                }
                
                return "Root : " + obj + " {" + children + "}";
            }
            else
            {
                if (this.HasChildren)
                {
                    string children = "";
                    for (int a = 0; a < 8; a++)
                    {
                        children += "[";
                        if (m_childNode[a] != null)
                            children += m_childNode[a].AllTreeObjects.length();
                        else
                            children += "0";
                        children += "]";
                    }
                    return "Branch : " + obj + " {" + children + "}";
                }
                else
                {
                    return "Leaf : " + obj;
                }
            }
        }

        /// <summary>
        /// Gives you a list of every single object within the whole octree.
        
        /// <returns>A list of Blob3D objects</returns>
     //   Blob3D[] AllObjects()
     //   {
     //       //Blob3D[] ret = Blob3D[]();
//
     //       //if(m_objects != null)
     //       //    ret.AddRange(m_objects);
//
     //       //if (HasChildren)
     //       //{
     //       //    for (int a = 0; a < 8; a++)
     //       //    {
     //       //        if (m_childNode[a] != null)
     //       //        {
     //       //            ret.AddRange(m_childNode[a].AllObjects());
     //       //        }
     //       //    }
     //       //}
//
     //       //return ret;
     //       get
     //       {
     //           return m_allObjects;
     //       }
     //   }

        /// <summary>
        /// Gives you a list of all objects within this tree and all of its children
        
        Blob3D[] AllTreeObjects()
        {
            get
            {
                Blob3D[] ret = Blob3D[]();

                if (m_objects != null)
                    ret.AddRange(m_objects);

                if (HasChildren)
                {
                    for (int a = 0; a < 8; a++)
                    {
                        if (m_childNode[a] != null)
                        {
                            ret.AddRange(m_childNode[a].AllTreeObjects);
                        }
                    }
                }

                return ret;
            }
        }

        int TotalObjects
        {
            get
            {
                return m_allObjects.length();
            }
        }

        private bool IsRoot
        {
            //The root node is the only node without a parent.
            get { return _parent == null; }
        }

        private bool HasChildren
        {
            get
            {
                return m_activeNodes != 0;
            }
        }

        /// <summary>
        /// Returns true if this node tree and all children have no content
        
        private bool IsEmpty    //untested
        {
            get
            {
                return m_allObjects.length() == 0;
                //if (m_objects == null)
                //    return true;
                //if (m_objects != null && m_objects.length() != 0)
                //    return false;
                //else
                //{
                //    for (int a = 0; a < 8; a++)
                //    {
                //        //note that we have to do this recursively. 
                //        //Just checking child nodes for the current node doesn't mean that their children won't have objects.
                //        if (m_childNode[a] != null && !m_childNode[a].IsEmpty)
                //            return false;
                //    }

                //    return true;
                //}
            }
        }
    }
}