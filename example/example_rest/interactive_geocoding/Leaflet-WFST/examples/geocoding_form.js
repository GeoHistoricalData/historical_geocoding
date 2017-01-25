
/*
 * Note : this function is about separating forme editing from base example
 */ 


//  var showSidebar = function (marker) {
//    sidebar._marker = marker;
//
//    if (sidebar._marker.feature) {
//      document.getElementById('idTextbox').value = sidebar._marker.feature.id || '';
//
//      if (sidebar._marker.feature.properties) {
//        document.getElementById('osmidTextbox').value = sidebar._marker.getProperty('osm_id') || '';
//        document.getElementById('manmadeTextbox').value = sidebar._marker.getProperty('man_made') || '';
//        document.getElementById('nameTextbox').value = sidebar._marker.getProperty('name') || '';
//        document.getElementById('amenityTextbox').value = sidebar._marker.getProperty('amenity') || '';
//        document.getElementById('leisureTextbox').value = sidebar._marker.getProperty('leisure') || '';
//        document.getElementById('officeTextbox').value = sidebar._marker.getProperty('office') || '';
//        document.getElementById('shopTextbox').value = sidebar._marker.getProperty('shop') || '';
//        document.getElementById('sportTextbox').value = sidebar._marker.getProperty('sport') || '';
//        document.getElementById('tourismTextbox').value = sidebar._marker.getProperty('tourism') || '';
//      }
//
//      sidebar._onApplyBtnClick = function () {
//        if (!sidebar._marker) {
//          return;
//        }
//
//        sidebar._marker.setProperties(sidebar._marker.feature.properties || {});
//
//        var propertiesChanged = false;
//
//        var applyPropertyValue = function (property, value) {
//          if ((property || value) && property !== value) {
//            property = value;
//            propertiesChanged = true;
//          }
//        };
//
//        sidebar._marker.setProperties({
//          osm_id:  document.getElementById('osmidTextbox').value || null,
//          man_made:  document.getElementById('manmadeTextbox').value || null,
//          name:  document.getElementById('nameTextbox').value || null,
//          amenity:  document.getElementById('amenityTextbox').value || null,
//          leisure:  document.getElementById('leisureTextbox').value || null,
//          office:  document.getElementById('officeTextbox').value || null,
//          shop:  document.getElementById('shopTextbox').value || null,
//          sport:  document.getElementById('sportTextbox').value || null,
//          tourism:  document.getElementById('tourismTextbox').value || null
//        })
//
//        if (propertiesChanged) {
//          sidebar._marker.fire('marker:edited');
//        }
//      };
//
//      var applyBtn = document.getElementById('applyButton');
//      L.DomEvent.on(applyBtn, 'click', sidebar._onApplyBtnClick);
//    }
//
//    sidebar.show();
//  };
  
  

//  var hideSidebar = function () {
//    if (sidebar._marker && sidebar._marker._popupToolbar && sidebar._marker._popupToolbar._removeToolbar) {
//      sidebar._marker._popupToolbar._removeToolbar();
//    }
//
//    var applyBtn = document.getElementById('applyButton');
//
//    if (sidebar._onApplyBtnClick) {
//      L.DomEvent.off(applyBtn, 'click', sidebar._onApplyBtnClick);
//    }
//
//    sidebar._marker = undefined;
//    sidebar._onApplyBtnClick = undefined;
//    sidebar.hide();
//  };
//
//  L.DomEvent.on(sidebar.getCloseButton(), 'click', function () {
//    hideSidebar();
//  });



//    marker.on('popuptoolbar:shown', function () {
//      showSidebar(marker);
//    });

//    marker.on('popuptoolbar:closed', function () {
//      hideSidebar();
//    });
