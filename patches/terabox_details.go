package terabox

// ListCloud patch: expose account storage usage so the admin storage list
// (/manage/storages) can show used / free / total for each mount.
//
// The upstream driver has no driver.WithDetails implementation, so
// /api/admin/storage/list always returns "mount_details": null for Terabox.
// /api/quota (the call the official web client makes) returns the numbers.

import (
	"context"
	"fmt"

	"github.com/OpenListTeam/OpenList/v4/internal/driver"
	"github.com/OpenListTeam/OpenList/v4/internal/model"
	"github.com/OpenListTeam/OpenList/v4/pkg/utils"
	log "github.com/sirupsen/logrus"
)

// GetDetails implements driver.WithDetails.
func (d *Terabox) GetDetails(ctx context.Context) (*model.StorageDetails, error) {
	if d.JsToken == "" {
		if err := d.resetJsToken(); err != nil {
			log.Debugf("[terabox] resetJsToken failed: %v", err)
		}
	}
	res, err := d.get("/api/quota", map[string]string{"clienttype": "0"}, nil)
	if err != nil {
		return nil, err
	}
	if len(res) == 0 {
		// resty does not surface transport-level failures for quota; retry once
		log.Debugln("[terabox] empty quota response, retrying after jsToken reset")
		if err = d.resetJsToken(); err != nil {
			return nil, err
		}
		if res, err = d.get("/api/quota", map[string]string{"clienttype": "0"}, nil); err != nil {
			return nil, err
		}
	}
	log.Debugf("[terabox] quota body: %s", string(res))
	errno := utils.Json.Get(res, "errno").ToInt()
	if errno != 0 {
		log.Debugf("[terabox] quota errno=%d body=%s", errno, string(res))
		return nil, fmt.Errorf("terabox quota failed, errno: %d", errno)
	}
	total := utils.Json.Get(res, "total").ToInt64()
	used := utils.Json.Get(res, "used").ToInt64()
	if total <= 0 {
		return nil, fmt.Errorf("terabox quota returned no data")
	}
	return &model.StorageDetails{
		DiskUsage: model.DiskUsage{
			TotalSpace: total,
			UsedSpace:  used,
		},
	}, nil
}

var _ driver.WithDetails = (*Terabox)(nil)
