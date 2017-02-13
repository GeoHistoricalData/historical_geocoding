
/*
 * Note : this function is about separating forme editing from base example
 */ 


  var showSidebar = function (marker) {
    sidebar._marker = marker;

    if (sidebar._marker.feature) {

      if (sidebar._marker.feature.properties) { //filling the form with values
        document.getElementById('hname').value = sidebar._marker.getProperty('historical_name') || '';
        document.getElementById('nname').value = sidebar._marker.getProperty('normalised_name') || ''; 
        document.getElementById('fdate').value = 0 ; //sidebar._marker.getProperty('normalised_name') || ''; 
        // @FIXME @DEBUG @ERROR //missing value returned from database 
        document.getElementById('hsource').value = sidebar._marker.getProperty('historical_source') || '';
        document.getElementById('nsource').value = sidebar._marker.getProperty('numerical_origin_process') || '';
        document.getElementById('adist').value = sidebar._marker.getProperty('aggregated_distance') || '';
        document.getElementById('sprecision').value = sidebar._marker.getProperty('spatial_precision') || '';
        document.getElementById('cresult').value = sidebar._marker.getProperty('confidence_in_result') || '';
        document.getElementById('sdist').value = sidebar._marker.getProperty('semantic_distance') || '';
        document.getElementById('tdist').value = sidebar._marker.getProperty('temporal_distance') || '';
        document.getElementById('ndist').value = sidebar._marker.getProperty('number_distance') || ''; 
      }

      sidebar._onApplyBtnClick = function () {
        if (!sidebar._marker) {
          return;
        }

        sidebar._marker.setProperties(sidebar._marker.feature.properties || {});

        var propertiesChanged = false;

        var applyPropertyValue = function (property, value) {
          if ((property || value) && property !== value) {
            property = value;
            propertiesChanged = true;
          }
        };

        sidebar._marker.setProperties({
          historical_name:  document.getElementById('hname').value || null,
          normalised_name:  document.getElementById('nname').value || null,
          //fuzzy_date:  document.getElementById('fdate').value || null,//@FIXME  
        })

        if (propertiesChanged) {
          sidebar._marker.fire('marker:edited');
        }
      };

//      var applyBtn = document.getElementById('applyButton');
//      L.DomEvent.on(applyBtn, 'click', sidebar._onApplyBtnClick);
    }
    console.log("showing the sidebar");
    sidebar_adress.hide();
    sidebar.show();
  };
  
  

  var hideSidebar = function () {
    if (sidebar._marker && sidebar._marker._popupToolbar && sidebar._marker._popupToolbar._removeToolbar) {
      sidebar._marker._popupToolbar._removeToolbar();
    }

    var applyBtn = document.getElementById('applyButton');

//    if (sidebar._onApplyBtnClick) {
//      L.DomEvent.off(applyBtn, 'click', sidebar._onApplyBtnClick);
//    }

    sidebar._marker = undefined;
    sidebar._onApplyBtnClick = undefined;
    sidebar_adress.show();
    sidebar.hide();
  };

//  L.DomEvent.on(sidebar.getCloseButton(), 'click', function () {
//    hideSidebar();
//  });


/*
    marker.on('popuptoolbar:shown', function () {
      showSidebar(marker);
    });

    marker.on('popuptoolbar:closed', function () {
      hideSidebar();
    });
*/
