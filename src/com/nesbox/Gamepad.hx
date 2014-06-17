package com.nesbox;

import com.nesbox.Gamepad.DomainPolicy;
import flash.desktop.NativeApplication;
import flash.display.Sprite;
import flash.errors.Error;
import flash.events.Event;
import flash.events.GameInputEvent;
import flash.events.ProgressEvent;
import flash.events.ServerSocketConnectEvent;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.html.HTMLLoader;
import flash.net.ServerSocket;
import flash.net.Socket;
import flash.net.URLRequest;
import flash.ui.GameInput;
import flash.ui.GameInputControl;
import flash.ui.GameInputDevice;
import flash.utils.ByteArray;
import haxe.Json;

/**
 * ...
 * @author Vadim Grigoruk
 */

@:file('assets/policy.xml')
class DomainPolicy extends ByteArray {}

private class ButtonType
{
	public static var Up = 'up';
	public static var Down = 'down';
	public static var Left = 'left';
	public static var Right = 'right';
	
	public static var Select = 'select';
	public static var Start = 'start';
	public static var L = 'l';
	public static var R = 'r';
	
	public static var A = 'a';
	public static var B = 'b';
	public static var C = 'c';
	
	public static var X = 'x';
	public static var Y = 'y';
	public static var Z = 'z';
}

private typedef Button =
{
	var type:String; // ButtonType
	var value:String;
}

private typedef Buttons = Array<Button>;

private typedef Window =
{
	var currentAssigningController:Int;
	var currentAssigningKey:String;
	var clearButton:Void->Void;
	
	function onGamepadKey(name:String):Void;
	function setStatusLabel(value:String, style:String):Void;
	function setFoundGamepads(count:Int):Void;
	function hideGamepadTabs():Void;
	function addGamepadTab(index:Int, name:String, buttons:Buttons):Void;
	function showDoesntSupport():Void;
}

private class Controller
{
	var device:GameInputDevice;
	var buttons:Buttons;
	
	public function new(device:GameInputDevice) 
	{
		this.device = device;
		
		load();
	}
	
	public function getButtons():Buttons
	{
		return buttons;
	}
	
	public function assignButton(type:String, name:String)
	{
		for (item in buttons)
		{
			if (item.type == type)
			{
				item.value = name;
			}
		}
		
		save();
	}
	
	public function getPressedButtons():Array<String>
	{
		var buttons = new Array<String>();
		
		for (index in 0...device.numControls)
		{
			var control = device.getControlAt(index);
			var value = control.value;
			var name = null;
			
			if (control.minValue == 0)
			{
				if (value == control.maxValue)
				{
					name = control.id;
				}
			}
			else
			{
				if (control.minValue * .5 >= value)
				{
					name = [control.id, 'MIN'].join(' ');
				}
				else if (control.maxValue * .5 <= value)
				{
					name = [control.id, 'MAX'].join(' ');
				}
			}
			
			if (name != null)
			{
				for (button in this.buttons)
				{
					buttons.push(name);
				}
			}
		}
		
		return buttons;
	}
	
	function getSettingsFile():File
	{
		var storageFolder = File.applicationStorageDirectory;
		return storageFolder.resolvePath('settings.json');
	}
	
	function readSettingsFile()
	{
		var settingsFile = getSettingsFile();
		
		if (settingsFile.exists)
		{
			var content = '';
			var stream = new FileStream();
			
			stream.open(settingsFile, FileMode.READ);
			content = stream.readUTF();
			stream.close();
			
			try
			{
				var settings = Json.parse(content);
				
				return settings;
			}
			catch (error:Error)
			{
				
			}
		}
		
		return { };
	}
	
	function load()
	{
		buttons = null;
		var uid = device.id;
		var settings = readSettingsFile();
		var loadedButtons = null;
		
		if (Reflect.hasField(settings, uid))
		{
			buttons = Reflect.field(settings, uid);
		}
		
		if(buttons == null)
		{
			buttons = getDefaultButtons();
			save();
		}
	}
	
	function save()
	{
		var settings = readSettingsFile();
		
		Reflect.setField(settings, device.id, buttons);
		
		var settingsFile = getSettingsFile();
		var content = Json.stringify(settings);
		
		var stream = new FileStream();
		
		stream.open(settingsFile, FileMode.WRITE);
		stream.writeUTF(content);
		stream.close();
	}
	
	function getDefaultButtons():Buttons
	{
		var buttonIndex = 0;
		var buttons:Buttons = [];
		
		for (index in 0...device.numControls)
		{
			var control = device.getControlAt(index);
			
			if (control.id.indexOf('AXIS_0') == 0)
			{
				buttons.push( { type:ButtonType.Left, value:control.id + ' MIN' } );
				buttons.push( { type:ButtonType.Right, value:control.id + ' MAX' } );
			}
			
			if (control.id.indexOf('AXIS_1') == 0)
			{
				buttons.push( { type:ButtonType.Up, value:control.id + ' MIN' } );
				buttons.push( { type:ButtonType.Down, value:control.id + ' MAX' } );
			}
			
			if (control.id.indexOf('BUTTON_') == 0)
			{
				if (buttonIndex == 0) buttons.push( { type:ButtonType.Select, value:control.id } );
				if (buttonIndex == 1) buttons.push( { type:ButtonType.Start, value:control.id } );
				if (buttonIndex == 2) buttons.push( { type:ButtonType.A, value:control.id } );
				if (buttonIndex == 3) buttons.push( { type:ButtonType.B, value:control.id } );
				if (buttonIndex == 4) buttons.push( { type:ButtonType.C, value:control.id } );
				if (buttonIndex == 5) buttons.push( { type:ButtonType.X, value:control.id } );
				if (buttonIndex == 6) buttons.push( { type:ButtonType.Y, value:control.id } );
				if (buttonIndex == 7) buttons.push( { type:ButtonType.Z, value:control.id } );
				if (buttonIndex == 8) buttons.push( { type:ButtonType.L, value:control.id } );
				if (buttonIndex == 9) buttons.push( { type:ButtonType.R, value:control.id } );
				
				buttonIndex++;
			}

		}
		
		return buttons;
	}
}

class Gamepad extends Sprite
{
	var window:Window;
	var gameInput:GameInput;
	var controllers:Array<Controller>;
	
	var serverSocket:ServerSocket;
	var securitySocket:ServerSocket;
	var clientSocket:Socket;
	
	var previousInput:UInt = 0;
	
	static var ButtonsOrder = 
	[
		ButtonType.Up,
		ButtonType.Down,
		ButtonType.Left,
		ButtonType.Right,
		
		ButtonType.A,
		ButtonType.B,
		ButtonType.C,

		ButtonType.X,
		ButtonType.Y,
		ButtonType.Z,

		ButtonType.Select,
		ButtonType.Start,
		
		ButtonType.L,
		ButtonType.R,
	];
	
	static var MaximumGamepads = 2;
	
	public function new() 
	{
		super();
		
		gameInput = new GameInput();
			
		gameInput.addEventListener(GameInputEvent.DEVICE_ADDED, onDeviceAdded);
		gameInput.addEventListener(GameInputEvent.DEVICE_REMOVED, onDeviceRemoved);
		
		addEventListener(Event.ADDED_TO_STAGE, init);
	}
	
	function createServer()
	{
		serverSocket = new ServerSocket();
		
		serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT, onServerConnect);
		serverSocket.addEventListener(Event.CLOSE, onServerDisconnect);
		serverSocket.bind(8087, '127.0.0.1');
		serverSocket.listen();
	}

	function setStatusLabelConnecting()
	{
		window.setStatusLabel('connecting to the website...', 'default');
	}
	
	function setStatusLabelConnected()
	{
		window.setStatusLabel('connected to the website', 'success');
	}
	
	function onServerDisconnect(event:Event)
	{
		clientSocket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
		clientSocket.removeEventListener(Event.CLOSE, onServerDisconnect);
		clientSocket = null;
		
		setStatusLabelConnecting();
	}
	
	function onServerConnect(event:ServerSocketConnectEvent)
	{
		clientSocket = event.socket;
		clientSocket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
		clientSocket.addEventListener(Event.CLOSE, onServerDisconnect);
		
		setStatusLabelConnected();
	}
	
	function onSocketData(event:ProgressEvent)
	{
		var socket = clientSocket;
		var buffer = new ByteArray();
		socket.readBytes(buffer, 0, socket.bytesAvailable);
		
		if (buffer.toString().indexOf('<policy-file-request/>') == 0)
		{
			socket.writeBytes(new DomainPolicy());
			socket.writeUnsignedInt(0);
			socket.flush();
		}
	}
	
	function createPooler()
	{
		stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
	}
	
	function onGamepadKey(name:String)
	{
		if (window.currentAssigningKey != null)
		{
			var type = window.currentAssigningKey.split('-')[0];
			
			var index = window.currentAssigningController;
			controllers[index].assignButton(type, name);
			
			window.onGamepadKey(name);
			
			window.currentAssigningKey = null;
		}
	}
	
	function onEnterFrame(event:Event)
	{
		var input:UInt = 0;
		
		if (controllers != null 
			&& controllers.length > 0)
		{
			for (controllerIndex in 0...controllers.length)
			{
				var controller = controllers[controllerIndex];
				var buttonNames = controller.getPressedButtons();
				var controllerInput:UInt = 0;
				var buttons = controller.getButtons();
				
				for (name in buttonNames)
				{
					onGamepadKey(name);
					
					for (button in buttons)
					{
						if (button.value == name)
						{
							var index = ButtonsOrder.indexOf(button.type);
					
							if (index != -1)
							{
								var mask:UInt = (1 << index);
								
								controllerInput |= mask;
							}
						}
					}
				}
				
				if (controllerIndex == 1)
				{
					controllerInput <<= 16;
				}
				
				if (controllerIndex == 0 || controllerIndex == 1)
					input |= controllerInput;
			}
			
			if (input != previousInput 
				&& clientSocket != null 
				&& clientSocket.connected)
			{
				clientSocket.writeUnsignedInt(input);
				clientSocket.flush();
				
				previousInput = input;
			}
		}
	}
	
	function init(event:Event)
	{
		var html = new HTMLLoader();
		
		html.load(new URLRequest('app:/html/index.html'));
		addChild(html);
		
		html.addEventListener(Event.COMPLETE, function(event:Event) 
		{
			window = html.window;
			
			start();
		});

		stage.addEventListener(Event.RESIZE, function(event:Event)
		{
			html.width = stage.stageWidth;
			html.height = stage.stageHeight;
		});

	}
	
	function createHandlers()
	{
		window.currentAssigningKey = null;
		window.currentAssigningController = 0;
		
		window.clearButton = function()
		{
			var index = window.currentAssigningController;
			var type = window.currentAssigningKey.split('-')[0];
			controllers[index].assignButton(type, null);
			
			window.onGamepadKey(null);
			
			window.currentAssigningKey = null;
		}
	}
	
	function start()
	{
		if (ServerSocket.isSupported && GameInput.isSupported)
		{
			createServer();
			createPooler();
			createHandlers();
			
			setStatusLabelConnecting();
			
			window.setFoundGamepads(GameInput.numDevices);
			
			refreshGamepads();
		}
		else
		{
			window.showDoesntSupport();
		}
	}
	
	function refreshGamepads()
	{
		if (window == null)
			return;
			
		window.setFoundGamepads(GameInput.numDevices);
		
		window.hideGamepadTabs();
		
		controllers = [];
		
		for (index in 0...GameInput.numDevices)
		{
			if (index >= MaximumGamepads)
				break;
				
			var device = GameInput.getDeviceAt(index);
			device.enabled = true;
			
			var controller = new Controller(device);
			
			controllers.push(controller);
			
			window.addGamepadTab(index, device.name, controller.getButtons());
		}
	}
	
	function onDeviceAdded(event:GameInputEvent)
	{
		refreshGamepads();
	}
	
	function onDeviceRemoved(event:GameInputEvent)
	{
		refreshGamepads();
	}

}