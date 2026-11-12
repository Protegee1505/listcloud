package dropbox

// ListCloud patch: expose account storage usage so the admin storage list
// (/manage/storages) can show used / free / total for each mount.
//
// The upstream driver has no driver.WithDetails implementation, so
// /api/admin/storage/list always returns "mount_details": null for Dropbox.
// /2/users/get_space_usage returns the allocation and the used bytes.

import (
	"context"
	"fmt"
	"net/http"

	"github.com/OpenListTeam/OpenList/v4/drivers/base"
	"github.com/OpenListTeam/OpenList/v4/internal/driver"
	"github.com/OpenListTeam/OpenList/v4/internal/errs"
	"github.com/OpenListTeam/OpenList/v4/internal/model"
	"github.com/OpenListTeam/OpenList/v4/pkg/utils"
	"github.com/go-resty/resty/v2"
	log "github.com/sirupsen/logrus"
)

// SpaceUsageResp mirrors
// https://www.dropbox.com/developers/documentation/http/documentation#users-get_space_usage
type SpaceUsageResp struct {
	Used       int64 `json:"used"`
	Allocation struct {
		Tag       string `json:".tag"`
		Allocated int64  `json:"allocated"`
	} `json:"allocation"`
}

// GetDetails implements driver.WithDetails.
func (d *Dropbox) GetDetails(ctx context.Context) (*model.StorageDetails, error) {
	if d.AccessToken == "" {
		return nil, errs.NotImplement
	}
	res, err := d.request("/2/users/get_space_usage", http.MethodPost, func(req *resty.Request) {
		req.SetContext(ctx).SetBody(base.Json{})
	})
	if err != nil {
		log.Debugf("[dropbox] get_space_usage failed: %v", err)
		return nil, err
	}
	log.Debugf("[dropbox] get_space_usage body: %s", string(res))
	var resp SpaceUsageResp
	if err = utils.Json.Unmarshal(res, &resp); err != nil {
		return nil, err
	}
	if resp.Allocation.Allocated <= 0 {
		return nil, fmt.Errorf("dropbox returned no allocation information")
	}
	return &model.StorageDetails{
		DiskUsage: model.DiskUsage{
			TotalSpace: resp.Allocation.Allocated,
			UsedSpace:  resp.Used,
		},
	}, nil
}

var _ driver.WithDetails = (*Dropbox)(nil)
