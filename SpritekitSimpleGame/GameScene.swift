//
//  GameScene.swift
//  SpritekitSimpleGame
//
//  Created by Beverly Lanning on 11/19/16.
//  Copyright © 2016 Beverly Lanning. All rights reserved.
//
//  Tutorial from
//  https://www.raywenderlich.com/145318/spritekit-swift-3-tutorial-beginners

import SpriteKit
import GameplayKit


// control player shooting
// explaination of math vector
// http://www.mathsisfun.com/algebra/vectors.html
func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

func - (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

func * (point: CGPoint, scalar: CGFloat) -> CGPoint {
    return CGPoint(x: point.x * scalar, y: point.y * scalar)
}

func / (point: CGPoint, scalar: CGFloat) -> CGPoint {
    return CGPoint(x: point.x / scalar, y: point.y / scalar)
}

#if !(arch(x86_64) || arch(arm64))
    func sqrt(a: CGFloat) -> CGFloat {
        return CGFloat(sqrtf(Float(a)))
    }
#endif

extension CGPoint {
    func length() -> CGFloat {
        return sqrt(x*x + y*y)
    }
    
    func normalized() -> CGPoint {
        return self / length()
    }
}


// player shooting physics
struct PhysicsCategory {
    static let None      : UInt32 = 0
    static let All       : UInt32 = UInt32.max
    static let Monster   : UInt32 = 0b1       // 1
    static let Projectile: UInt32 = 0b10      // 2
}


class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // 1
    let player = SKSpriteNode(imageNamed: "player")
    
    var monstersDestroyed = 0
    
    override func didMove(to view: SKView) {
        // 2
        backgroundColor = SKColor.white
        // 3
        player.position = CGPoint(x: size.width * 0.1, y: size.height * 0.5)
        // 4
        addChild(player)
        // unleash monsters
        run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.run(addMonster),
                SKAction.wait(forDuration: 1.0)
                ])
        ))
        // Sets up the physics world to have no gravity, and sets the scene as the delegate
        // to be notified when two physics bodies collide.
        physicsWorld.gravity = CGVector.zero
        physicsWorld.contactDelegate = self
        
        let backgroundMusic = SKAudioNode(fileNamed: "background-music-aac.caf")
        backgroundMusic.autoplayLooped = true
        addChild(backgroundMusic)
    }
   /* 
    1. Declare a private constant for the player (i.e. the ninja), which is an example of a sprite.
    2. Setting the background color of a scene in SpriteKit. Set it to white.
    3. Position the sprite to be 10% across vertically, and centered horizontally.
    4. To make the sprite appear on the scene, must add it as a child of the scene. Similar to making views children of other views.
    */
    
    
    func random() -> CGFloat {
        return CGFloat(Float(arc4random()) / 0xFFFFFFFF)
    }
    
    func random(min: CGFloat, max: CGFloat) -> CGFloat {
        return random() * (max - min) + min
    }
    
    
    func addMonster() {
        
        // Create sprite
        let monster = SKSpriteNode(imageNamed: "monster")
        
        monster.physicsBody = SKPhysicsBody(rectangleOf: monster.size) // 1
        monster.physicsBody?.isDynamic = true // 2
        monster.physicsBody?.categoryBitMask = PhysicsCategory.Monster // 3
        monster.physicsBody?.contactTestBitMask = PhysicsCategory.Projectile // 4
        monster.physicsBody?.collisionBitMask = PhysicsCategory.None // 5
        /*
         1. Creates a physics body for the sprite. In this case, the body is defined as a rectangle of the same size of the sprite, because that’s a decent approximation for the monster.
         2. Sets the sprite to be dynamic. This means that the physics engine will not control the movement of the monster – you will through the code you’ve already written (using move actions).
         3. Sets the category bit mask to be the monsterCategory you defined earlier.
         4. The contactTestBitMask indicates what categories of objects this object should notify the contact listener when they intersect. You choose projectiles here.
         5. The collisionBitMask indicates what categories of objects this object that the physics engine handle contact responses to (i.e. bounce off of). You don’t want the monster and projectile to bounce off each other – it’s OK for them to go right through each other in this game – so set this to 0.
         */
        
        // Determine where to spawn the monster along the Y axis
        let actualY = random(min: monster.size.height/2, max: size.height - monster.size.height/2)
        
        // Position the monster slightly off-screen along the right edge,
        // and along a random position along the Y axis as calculated above
        monster.position = CGPoint(x: size.width + monster.size.width/2, y: actualY)
        
        // Add the monster to the scene
        addChild(monster)
        
        // Determine speed of the monster
        let actualDuration = random(min: CGFloat(2.0), max: CGFloat(4.0))
        
        // Create the actions
        let actionMove = SKAction.move(to: CGPoint(x: -monster.size.width/2, y: actualY), duration: TimeInterval(actualDuration))
        let actionMoveDone = SKAction.removeFromParent()
        let loseAction = SKAction.run() {
            let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
            let gameOverScene = GameOverScene(size: self.size, won: false)
            self.view?.presentScene(gameOverScene, transition: reveal)
        }
        monster.run(SKAction.sequence([actionMove, loseAction, actionMoveDone]))
        
    }
    
    /*
     - SKAction.move(to::duration:): You use this action to direct the object to move off-screen to the left. Note that you can specify the duration for how long the movement should take, and here you vary the speed randomly from 2-4 seconds.
     
     - SKAction.removeFromParent(): SpriteKit comes with a handy action that removes a node from its parent, effectively “deleting it” from the scene. Here you use this action to remove the monster from the scene when it is no longer visible. This is important because otherwise you’d have an endless supply of monsters and would eventually consume all device resources.
     
     - SKAction.sequence(_:): The sequence action allows you to chain together a sequence of actions that are performed in order, one at a time. This way, you can have the “move to” action perform first, and once it is complete perform the “remove from parent” action.
     */
    
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        // 1 - Choose one of the touches to work with
        guard let touch = touches.first else {
            return
        }
        let touchLocation = touch.location(in: self)
        
        // 2 - Set up initial location of projectile
        let projectile = SKSpriteNode(imageNamed: "projectile")
        projectile.position = player.position
        
        projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectile.size.width/2)
        projectile.physicsBody?.isDynamic = true
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.Projectile
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.Monster
        projectile.physicsBody?.collisionBitMask = PhysicsCategory.None
        projectile.physicsBody?.usesPreciseCollisionDetection = true
        
        // 3 - Determine offset of location to projectile
        let offset = touchLocation - projectile.position
        
        // 4 - Bail out if shooting down or backwards
        if (offset.x < 0) { return }
        
        // 5 - OK to add now, double checked position
        addChild(projectile)
        
        // 6 - Get the direction of where to shoot
        let direction = offset.normalized()
        
        // 7 - Make it shoot far enough to be guaranteed off screen
        let shootAmount = direction * 1000
        
        // 8 - Add the shoot amount to the current position
        let realDest = shootAmount + projectile.position
        
        // 9 - Create the actions
        let actionMove = SKAction.move(to: realDest, duration: 2.0)
        let actionMoveDone = SKAction.removeFromParent()
        projectile.run(SKAction.sequence([actionMove, actionMoveDone]))
        
        
        run(SKAction.playSoundFileNamed("pew-pew-lei.caf", waitForCompletion: false))
    }
    /*
     1. One of the cool things about SpriteKit is that it includes a category on UITouch with location(in:) and previousLocation(in:) methods. These let you find the coordinate of a touch within a SKNode’s coordinate system. In this case, you use it to find out where the touch is within the scene’s coordinate system.
     2. You then create a projectile and place it where the player is to start. Note you don’t add it to the scene yet, because you have to do some sanity checking first – this game does not allow the ninja to shoot backwards.
     3. You then subtract the projectile’s current position from the touch location to get a vector from the current position to the touch location.
     4. If the X value is less than 0, this means the player is trying to shoot backwards. This is is not allowed in this game (real ninjas don’t look back!), so just return.
     5. Otherwise, it’s OK to add the projectile to the scene.
     6. Convert the offset into a unit vector (of length 1) by calling normalized(). This will make it easy to make a vector with a fixed length in the same direction, because 1 * length = length.
     7. Multiply the unit vector in the direction you want to shoot in by 1000. Why 1000? It will definitely be long enough to go past the edge of the screen :]
     8. Add the shoot amount to the current position to get where it should end up on the screen.
     9. Finally, create move(to:, duration:) and removeFromParent() actions like you did earlier for the monster.
     */


    /* collision detection and physics
     - Set up the physics world. A physics world is the simulation space for running physics calculations. One is set up on the scene by default, and you might want to configure a few properties on it, like gravity.
     
     - Create physics bodies for each sprite. In SpriteKit, you can associate a shape to each sprite for collision detection purposes, and set certain properties on it. This is called a physics body. Note that the physics body does not have to be the exact same shape as the sprite. Usually it’s a simpler, approximate shape rather than pixel-perfect, since that is good enough for most games and performant.
     
     - Set a category for each type of sprite. One of the properties you can set on a physics body is a category, which is a bitmask indicating the group (or groups) it belongs to. In this game, you’re going to have two categories – one for projectiles, and one for monsters. Then later when two physics bodies collide, you can easily tell what kind of sprite you’re dealing with by looking at its category.
     
     - Set a contact delegate. Remember that physics world from earlier? Well, you can set a contact delegate on it to be notified when two physics bodies collide. There you’ll write some code to examine the categories of the objects, and if they’re the monster and projectile, you’ll make them go boom!
     */
    

    func projectileDidCollideWithMonster(projectile: SKSpriteNode, monster: SKSpriteNode) {
        print("Hit")
        projectile.removeFromParent()
        monster.removeFromParent()
        monstersDestroyed += 1
        if (monstersDestroyed > 10) {
            let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
            let gameOverScene = GameOverScene(size: self.size, won: true)
            self.view?.presentScene(gameOverScene, transition: reveal)
        }
    }
    
    
    func didBegin(_ contact: SKPhysicsContact) {
        
        // 1
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        // 2
        if ((firstBody.categoryBitMask & PhysicsCategory.Monster != 0) &&
            (secondBody.categoryBitMask & PhysicsCategory.Projectile != 0)) {
            projectileDidCollideWithMonster(projectile: firstBody.node as! SKSpriteNode, monster: secondBody.node as! SKSpriteNode)
        }
        
    }
    /*
     1. Passes the two bodies that collide, but does not guarantee that they are passed in any particular order. So this bit of code just arranges them so they are sorted by their category bit masks so you can make some assumptions later.
     2. Finally, checks to see if the two bodies that collide are the projectile and monster, and if so calls the method wrote earlier.
     */
}
