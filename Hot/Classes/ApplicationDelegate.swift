/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2020 Jean-David Gadina - www.xs-labs.com
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Cocoa
import GitHubUpdates

@NSApplicationMain
class ApplicationDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate
{
    private var statusItem:                  NSStatusItem?
    private var aboutWindowController:       AboutWindowController?
    private var preferencesWindowController: PreferencesWindowController?
    private var sensorsWindowController:     SensorsWindowController?
    private var sensorViewControllers:       [ SensorViewController  ] = []
    
    @IBOutlet private var menu:        NSMenu!
    @IBOutlet private var sensorsMenu: NSMenu!
    @IBOutlet private var updater:     GitHubUpdater!
    
    @objc public private( set ) dynamic var infoViewController: InfoViewController?
    
    deinit
    {
        UserDefaults.standard.removeObserver( self, forKeyPath: "displayCPUTemperature" )
        UserDefaults.standard.removeObserver( self, forKeyPath: "colorizeStatusItemText" )
        UserDefaults.standard.removeObserver( self, forKeyPath: "convertToFahrenheit" )
        UserDefaults.standard.removeObserver( self, forKeyPath: "hideStatusIcon" )
    }
    
    func applicationDidFinishLaunching( _ notification: Notification )
    {
        if UserDefaults.standard.object( forKey: "LastLaunch" ) == nil
        {
            UserDefaults.standard.setValue( true,     forKey: "automaticallyCheckForUpdates" )
            UserDefaults.standard.setValue( true,     forKey: "displayCPUTemperature" )
            UserDefaults.standard.setValue( true,     forKey: "colorizeStatusItemText" )
            UserDefaults.standard.setValue( NSDate(), forKey: "LastLaunch" )
        }
        
        if UserDefaults.standard.object( forKey: "refreshInterval" ) == nil
        {
            UserDefaults.standard.setValue( 2, forKey: "refreshInterval" )
        }
        
        if UserDefaults.standard.object( forKey: "sensorsWindowShowTemperature" ) == nil
        {
            UserDefaults.standard.setValue( true, forKey: "sensorsWindowShowTemperature" )
        }
        
        if UserDefaults.standard.object( forKey: "sensorsWindowShowVoltage" ) == nil
        {
            UserDefaults.standard.setValue( true, forKey: "sensorsWindowShowVoltage" )
        }
        
        if UserDefaults.standard.object( forKey: "sensorsWindowShowCurrent" ) == nil
        {
            UserDefaults.standard.setValue( true, forKey: "sensorsWindowShowCurrent" )
        }
        
        self.aboutWindowController             = AboutWindowController()
        self.preferencesWindowController       = PreferencesWindowController()
        self.statusItem                        = NSStatusBar.system.statusItem( withLength: NSStatusItem.variableLength )
        self.statusItem?.button?.image         = NSImage( named: "StatusIconTemplate" )
        self.statusItem?.button?.imagePosition = .imageLeading
        self.statusItem?.menu                  = self.menu
        
        self.updateMenuFont()
        
        let infoViewController             = InfoViewController()
        self.infoViewController            = infoViewController
        self.menu.item( withTag: 1 )?.view = infoViewController.view
        self.infoViewController?.onUpdate  =
        {
            [ weak self ] in
            
            self?.updateTitle()
            self?.updateSensors()
        }
        
        UserDefaults.standard.addObserver( self, forKeyPath: "displayCPUTemperature",  options: [], context: nil )
        UserDefaults.standard.addObserver( self, forKeyPath: "colorizeStatusItemText", options: [], context: nil )
        UserDefaults.standard.addObserver( self, forKeyPath: "convertToFahrenheit",    options: [], context: nil )
        UserDefaults.standard.addObserver( self, forKeyPath: "hideStatusIcon",         options: [], context: nil )
        UserDefaults.standard.addObserver( self, forKeyPath: "fontName",               options: [], context: nil )
        
        if UserDefaults.standard.bool( forKey: "automaticallyCheckForUpdates" )
        {
            DispatchQueue.main.asyncAfter( deadline: .now() + .seconds( 2 ) )
            {
                self.updater.checkForUpdatesInBackground()
            }
        }
        
        Timer.scheduledTimer( withTimeInterval: 3600, repeats: true )
        {
            _ in 
            
            if UserDefaults.standard.bool( forKey: "automaticallyCheckForUpdates" )
            {
                self.updater.checkForUpdatesInBackground()
            }
        }
    }
    
    private func updateMenuFont()
    {
        let system = NSFont.monospacedDigitSystemFont( ofSize: NSFont.smallSystemFontSize, weight: .light )
        
        guard let fontName = UserDefaults.standard.string( forKey: "fontName" ) else
        {
            self.statusItem?.button?.font = system
            
            return
        }
        
        let parts = fontName.split( separator: " " )
        
        guard parts.count >= 2, let last = parts.last, let size = Int( String( last ) ) else
        {
            self.statusItem?.button?.font = system
            
            return
        }
        
        let name                      = parts.dropLast().joined( separator: " " )
        self.statusItem?.button?.font = NSFont( name: name, size: CGFloat( size ) ) ?? system
    }
    
    override func observeValue( forKeyPath keyPath: String?, of object: Any?, change: [ NSKeyValueChangeKey : Any ]?, context: UnsafeMutableRawPointer? )
    {
        let keyPaths =
        [
            "displayCPUTemperature",
            "colorizeStatusItemText",
            "convertToFahrenheit",
            "hideStatusIcon",
            "fontName"
        ]
        
        if let keyPath = keyPath, let object = object as? NSObject, object == UserDefaults.standard && keyPaths.contains( keyPath )
        {
            self.updateMenuFont()
            self.updateTitle()
            self.updateSensors()
        }
        else
        {
            super.observeValue( forKeyPath: keyPath, of: object, change: change, context: context )
        }
    }
    
    @IBAction public func showAboutWindow( _ sender: Any? )
    {
        guard let window = self.aboutWindowController?.window else
        {
            NSSound.beep()
            
            return
        }
        
        if window.isVisible == false
        {
            window.layoutIfNeeded()
            window.center()
        }
        
        NSApp.activate( ignoringOtherApps: true )
        window.makeKeyAndOrderFront( nil )
    }
    
    @IBAction public func showPreferencesWindow( _ sender: Any? )
    {
        guard let window = self.preferencesWindowController?.window else
        {
            NSSound.beep()
            
            return
        }
        
        if window.isVisible == false
        {
            window.layoutIfNeeded()
            window.center()
        }
        
        NSApp.activate( ignoringOtherApps: true )
        window.makeKeyAndOrderFront( nil )
    }
    
    @IBAction public func checkForUpdates( _ sender: Any? )
    {
        self.updater.checkForUpdates( sender )
    }
    
    private func updateTitle()
    {
        var title       = ""
        let transformer = TemperatureToString()
        
        if let n1 = self.infoViewController?.speedLimit,
           let n2 = self.infoViewController?.cpuTemperature,
           UserDefaults.standard.bool( forKey: "displayCPUTemperature" ),
           n1 > 0,
           n2 > 0
        {
            let temp = transformer.transformedValue( n2 ) as? String ?? "--"
            title    = "\( n1 )% \( temp )"
        }
        else if let n = self.infoViewController?.speedLimit, n > 0
        {
            title = "\( n )%"
        }
        else if let n = self.infoViewController?.cpuTemperature,
                UserDefaults.standard.bool( forKey: "displayCPUTemperature" ),
                n > 0
        {
            title = transformer.transformedValue( n ) as? String ?? "--"
        }
        
        if title.count == 0
        {
            self.statusItem?.button?.title = ""
        }
        else
        {
            let color: NSColor =
            {
                if UserDefaults.standard.bool( forKey: "colorizeStatusItemText" ) == false
                {
                    return .controlTextColor
                }
                
                let limit = self.infoViewController?.speedLimit ?? 100
                
                if limit > 0 && limit < 60
                {
                    return .orange
                }
                
                if let rawPressure = self.infoViewController?.thermalPressure,
                   let pressure    = ProcessInfo.ThermalState( rawValue: rawPressure ),
                       pressure   != .nominal
                {
                    return .orange
                }
                
                return .controlTextColor
            }()
            
            self.statusItem?.button?.attributedTitle = NSAttributedString( string: title, attributes: [ .foregroundColor : color ] )
        }
        
        if UserDefaults.standard.bool( forKey: "hideStatusIcon" ) && title.count > 0
        {
            self.statusItem?.button?.image = nil
        }
        else
        {
            self.statusItem?.button?.image = NSImage( named: "StatusIconTemplate" )
        }
    }
    
    private func updateSensors()
    {
        let sortsensorlist = self.infoViewController?.log.sensors.sorted
        {
            $0.key.compare( $1.key, options: .numeric, range: nil, locale: nil ) == .orderedAscending
        }
        
        if (self.sensorViewControllers.isEmpty)
        {
            self.sensorsMenu.removeAllItems() // there is one menu item already in the menu item list there at the start of application (name 'Item') so we clear it
            
            // only create the menu item list in submenu the first time from scratch since this needs CPU time! It loads fresh icons for each item with each SensorViewController() call.
            sortsensorlist?.forEach
            {
                let controller   = SensorViewController()
                controller.name  = $0.key
                controller.value = Int( $0.value )
                let item         = NSMenuItem( title: $0.key, action: nil, keyEquivalent: "" )
                item.view        = controller.view
                
                // create menu item list in same order as sensor list
                self.sensorsMenu.addItem( item )
                // also create a viewcontroller list with same order
                self.sensorViewControllers.append(controller)
            }
        }
        else
        {
            // if item list is already there just update the value inside each viewcontroller item
            var menuIndex = 0
            sortsensorlist?.forEach
            {
                // since viewcontroler list was created in same order as sensor list simply access by index now.
                let viewcontroller = self.sensorViewControllers[menuIndex]
                viewcontroller.value = Int( $0.value )
                menuIndex = menuIndex + 1
            }
        }
    }
    
    @IBAction public func viewAllSensors( _ sender: Any? )
    {
        #if arch( arm64 )
        
        if self.sensorsWindowController == nil
        {
            self.sensorsWindowController = SensorsWindowController()
        }
        
        guard let window = self.sensorsWindowController?.window else
        {
            NSSound.beep()
            
            return
        }
        
        window.delegate = self
        
        if window.isVisible == false
        {
            window.layoutIfNeeded()
            window.center()
        }
        
        NSApp.activate( ignoringOtherApps: true )
        window.makeKeyAndOrderFront( nil )
        
        #else
        
        let alert             = NSAlert()
        alert.messageText     = "Feature not available"
        alert.informativeText = "This feature is only available for Macs with ARM processors."
        
        alert.runModal()
        
        #endif
    }
    
    func windowWillClose( _ notification: Notification )
    {
        self.sensorsWindowController?.stop()
        
        self.sensorsWindowController = nil
    }
}
