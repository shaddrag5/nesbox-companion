package com.nesbox;

import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.Lib;

import flash.events.Event;
import flash.events.MouseEvent;
import flash.events.InvokeEvent;

/**
 * ...
 * @author Vadim Grigoruk
 */

class Main 
{
	static function main() 
	{
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		Lib.current.stage.align = StageAlign.TOP_LEFT;
		
		var gamepad = new Gamepad();
		Lib.current.addChild(gamepad);
	}
}